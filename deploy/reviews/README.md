Place the actual clinical advisor's review record here before enabling reviewed
production guidance. Never fabricate approval. `clinical-review.json` must contain:

```json
{
  "approved": true,
  "reviewer": "Actual advisor identity and credentials",
  "reviewed_at": "An actual ISO-8601 timestamp with timezone",
  "content_sha256": "SHA-256 of the exact reviewed catalogue"
}
```

Generate the catalogue digest from `backend/` using:

```
python -c "from app.healthbot.review import content_digest; print(content_digest())"
```

The record approves the static knowledge/action catalogue only. It does not
constitute approval of every generated paraphrase or clinical validation of ML.
Production release still needs the advisor's agreed protocol for generated
answers. Changing the catalogue invalidates the record.
