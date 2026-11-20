"""Add required group indexes, preserving all current single-field indexes.

Dry-run by default. python tools/ensure_indexes.py --apply makes additive changes
only, using the project's configured Firebase service account.
"""
import argparse
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from google.auth.transport.requests import AuthorizedSession
from app.dependencies import get_firebase_identity_provider


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    app = get_firebase_identity_provider()._ensure_app()
    session = AuthorizedSession(app.credential.get_credential())
    for group, field in [('cravingLogs', 'riskAssessmentPending'), ('habitAlternativeAttempts', 'outcomeHelped'), ('reminderSchedules', 'enabled')]:
        name = f'projects/{app.project_id}/databases/(default)/collectionGroups/{group}/fields/{field}'
        url = f'https://firestore.googleapis.com/v1/{name}'
        response = session.get(url, timeout=20)
        response.raise_for_status()
        current = response.json().get('indexConfig', {}).get('indexes', [])
        if any(index.get('queryScope') == 'COLLECTION_GROUP' and index.get('fields', [{}])[0].get('order') == 'ASCENDING' for index in current):
            print(f'{group}.{field}: group index already configured')
            continue
        indexes = [{key: value for key, value in index.items() if key in {'queryScope', 'fields'}} for index in current]
        if not indexes:
            indexes = [{'queryScope': 'COLLECTION', 'fields': [{'fieldPath': field, 'order': order}]} for order in ['ASCENDING', 'DESCENDING']]
        indexes.append({'queryScope': 'COLLECTION_GROUP', 'fields': [{'fieldPath': field, 'order': 'ASCENDING'}]})
        print(f'{group}.{field}: add group index; preserve {len(indexes) - 1} existing indexes')
        if args.apply:
            result = session.patch(url, params={'updateMask': 'indexConfig'}, json={'name': name, 'indexConfig': {'indexes': indexes}}, timeout=30)
            result.raise_for_status()
            print('Index build submitted')


if __name__ == '__main__': main()
