import os
import re
import datetime
from pathlib import Path
from zoneinfo import ZoneInfo
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from icalendar import Calendar
from dateutil.rrule import rrulestr

def parse_gcal_time(time_dict):
    if not time_dict:
        return None
    if 'dateTime' in time_dict:
        val = time_dict['dateTime']
        if val.endswith('Z'):
            val = val[:-1] + '+00:00'
        return datetime.datetime.fromisoformat(val)
    elif 'date' in time_dict:
        return datetime.date.fromisoformat(time_dict['date'])
    return None

def extract_categories(component):
    cats = component.get('categories')
    if not cats:
        return []
    result = []
    if hasattr(cats, 'cats'):
        result.extend(str(c) for c in cats.cats)
    elif isinstance(cats, list):
        for cat in cats:
            if hasattr(cat, 'cats'):
                result.extend(str(c) for c in cat.cats)
            else:
                result.append(str(cat))
    else:
        result.append(str(cats))
    return [c.strip() for c in result]

def is_academic(categories):
    for cat in categories:
        if 'academic' in cat.lower():
            return True
    return False

def is_done(categories):
    for cat in categories:
        if cat.strip().upper() == 'DONE':
            return True
    return False

NON_CLASS_TAGS = {
    'academic', 'general', 'project', 'projects', 'personal', 'config',
    'arch', 'emacs', 'homeserver', 'errands', 'inbox', 'calendar', 'tea',
    'todo', 'done', 'next', 'hold', 'waiting', 'cancelled', 'someday', 'canceled',
    'event', 'note', 'habit'
}

def get_class_prefix(categories):
    for cat in categories:
        c = cat.strip()
        if re.match(r'^[A-Za-z]{2,5}\s?\d{3,5}[A-Za-z]?$', c):
            return c
    if is_academic(categories):
        for cat in categories:
            c = cat.strip()
            if c.lower() not in NON_CLASS_TAGS:
                return c
    return None

def format_summary(summary, categories):
    class_prefix = get_class_prefix(categories)
    if class_prefix:
        summary = re.sub(r'^(DL|S):\s*', f'{class_prefix}: ', summary)
    return summary

def instances(component, now, count=2):
    """(uid, start, end) tuples to sync for one VEVENT.

    Plain-timestamp repeaters (org exports them with TS UIDs) expand to their next
    `count` occurrences, each with its own UID, so Google never gets an endless RRULE.
    An occurrence counts until it ends. Repeating SCHEDULED/DEADLINE items stay single.
    """
    if component.name != "VEVENT":
        return []
    uid = str(component.get('uid'))
    start = component.get('dtstart').dt
    end = component.get('dtend').dt if component.get('dtend') else start
    rule = component.get('rrule')
    if not rule or not uid.startswith('TS'):
        return [(uid, start, end)]

    timed = isinstance(start, datetime.datetime)
    if timed:
        s, e = start.replace(tzinfo=None), end.replace(tzinfo=None)
        threshold = now.astimezone(start.tzinfo or LOCAL_TZ).replace(tzinfo=None) - (e - s)
    else:
        s = datetime.datetime.combine(start, datetime.time.min)
        e = datetime.datetime.combine(end, datetime.time.min)
        threshold = datetime.datetime.combine(now.astimezone(LOCAL_TZ).date(), datetime.time.min)
    rr = rrulestr(rule.to_ical().decode(), dtstart=s)

    out = []
    occ = rr.after(threshold, inc=True)
    while occ and len(out) < count:
        occ_end = occ + (e - s)
        if timed:
            pair = (occ.replace(tzinfo=start.tzinfo), occ_end.replace(tzinfo=start.tzinfo))
        else:
            pair = (occ.date(), occ_end.date())
        out.append((f"{uid}-{occ:%Y%m%d}", *pair))
        occ = rr.after(occ)
    return out

SCOPES = ['https://www.googleapis.com/auth/calendar']
CALENDAR_ID = "e3d89532ba31ee6d116006a705b33b2270786cb9cf3907a10a9c7da76b6634c9@group.calendar.google.com"
LOCAL_TZ = ZoneInfo("America/New_York")

def get_gcal_service():
    creds = None
    token_path = Path('/home/doa/org/gcal/token.json')
    creds_path = Path('/home/doa/org/gcal/credentials.json')
    if token_path.exists():
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(str(creds_path), SCOPES)
            creds = flow.run_local_server(port=0)
        with token_path.open('w') as token:
            token.write(creds.to_json())
    return build('calendar', 'v3', credentials=creds)

def sync_calendar():
    service = get_gcal_service()
    
    today_date = datetime.date.today()
    now_datetime = datetime.datetime.now(LOCAL_TZ)
    
    # 1. FETCH LIVE FUTURE EVENTS & CLEAR DUPLICATES IMMEDIATELY
    # Fetch events starting from the beginning of today (local time) to avoid timezone/midnight crossover issues
    start_of_today = datetime.datetime.combine(today_date, datetime.time.min).replace(tzinfo=LOCAL_TZ)
    time_min_utc = start_of_today.astimezone(datetime.timezone.utc).isoformat()
    
    gcal_events = {} # Maps unique iCalUID -> a single target Google Event ID
    page_token = None
    
    while True:
        events_result = service.events().list(
            calendarId=CALENDAR_ID, timeMin=time_min_utc, 
            singleEvents=True, pageToken=page_token
        ).execute()
        
        for item in events_result.get('items', []):
            uid = item.get('iCalUID')
            if uid:
                # If we've already tracked this UID during this session, it's a duplicate!
                # Delete it immediately on the spot to clean up the backend.
                if uid in gcal_events:
                    print(f"Cleaning up legacy cloud duplicate: {item.get('summary')}")
                    try:
                        service.events().delete(calendarId=CALENDAR_ID, eventId=item['id']).execute()
                    except Exception:
                        pass
                else:
                    # Otherwise, track this as the primary valid entry
                    gcal_events[uid] = item
                
        page_token = events_result.get('nextPageToken')
        if not page_token:
            break

    # 2. PARSE LOCAL ICS FILE & CALCULATE DELTAS
    ics_path = Path.home() / 'org' / 'org-agenda.ics'
    local_future_uids = set()
    
    with ics_path.open('rb') as f:
        gcal_parsed = Calendar.from_ical(f.read())
        
        for component in gcal_parsed.walk():
            for uid, start, end in instances(component, now_datetime):
                summary = str(component.get('summary'))
                
                if isinstance(end, datetime.datetime):
                    end_check = end.replace(tzinfo=LOCAL_TZ) if end.tzinfo is None else end.astimezone(LOCAL_TZ)
                    if end_check < now_datetime:
                        continue
                else:
                    if start < today_date:
                        continue
                
                local_future_uids.add(uid)
                
                # Extract categories and determine color:
                # Gray (colorId '8') for DONE tasks, Pistachio (colorId '2') for active academic tags/courses
                categories = extract_categories(component)
                if is_done(categories):
                    local_color = '8'
                elif is_academic(categories):
                    local_color = '2'
                else:
                    local_color = None
                summary = format_summary(summary, categories)
                
                # Normalize times and create the body
                if isinstance(start, datetime.datetime):
                    local_start = start.replace(tzinfo=LOCAL_TZ) if start.tzinfo is None else start
                    local_end = end.replace(tzinfo=LOCAL_TZ) if end.tzinfo is None else end
                    event_body = {
                        'summary': summary,
                        'iCalUID': uid,
                        'start': {'dateTime': local_start.isoformat()},
                        'end': {'dateTime': local_end.isoformat()}
                    }
                else:
                    local_start = start
                    local_end = end
                    event_body = {
                        'summary': summary,
                        'iCalUID': uid,
                        'start': {'date': local_start.isoformat()},
                        'end': {'date': local_end.isoformat()}
                    }
                
                if local_color:
                    event_body['colorId'] = local_color

                local_location = str(component.get('location') or '').strip()
                if local_location:
                    event_body['location'] = local_location

                if uid in gcal_events:
                    gcal_event = gcal_events[uid]
                    gcal_start = parse_gcal_time(gcal_event.get('start'))
                    gcal_end = parse_gcal_time(gcal_event.get('end'))
                    gcal_summary = gcal_event.get('summary', '')
                    gcal_color = gcal_event.get('colorId')
                    
                    # Check for changes in summary, start time, end time, or color
                    has_changes = False
                    if gcal_summary != summary:
                        has_changes = True
                    elif gcal_start != local_start:
                        has_changes = True
                    elif gcal_end != local_end:
                        has_changes = True
                    elif gcal_color != local_color:
                        has_changes = True
                    elif gcal_event.get('location', '') != local_location:
                        has_changes = True
                        
                    if has_changes:
                        print(f"Updating existing event with changes: {summary}")
                        service.events().update(
                            calendarId=CALENDAR_ID,
                            eventId=gcal_event['id'],
                            body=event_body
                        ).execute()
                    continue
                
                # Check for a fallback match by summary and start/end time
                fallback_match = None
                fallback_uid = None
                for g_uid, g_event in gcal_events.items():
                    g_start = parse_gcal_time(g_event.get('start'))
                    g_end = parse_gcal_time(g_event.get('end'))
                    g_summary = g_event.get('summary', '')
                    if g_summary == summary and g_start == local_start and g_end == local_end:
                        fallback_match = g_event
                        fallback_uid = g_uid
                        break
                        
                if fallback_match:
                    print(f"UID changed for event '{summary}'. Migrating to new UID on Google Calendar...")
                    service.events().update(
                        calendarId=CALENDAR_ID,
                        eventId=fallback_match['id'],
                        body=event_body
                    ).execute()
                    # Update tracking
                    gcal_events[uid] = fallback_match
                    if fallback_uid in gcal_events and fallback_uid != uid:
                        del gcal_events[fallback_uid]
                    continue
                
                print(f"Adding new future event: {summary}")
                service.events().insert(calendarId=CALENDAR_ID, body=event_body).execute()

    # 3. PURGE REMOVED EVENTS
    for uid, gcal_event in gcal_events.items():
        if uid not in local_future_uids:
            print(f"Removing deleted local target from Google Calendar: {gcal_event.get('summary')}")
            try:
                service.events().delete(calendarId=CALENDAR_ID, eventId=gcal_event['id']).execute()
            except Exception:
                pass

if __name__ == '__main__':
    sync_calendar()
