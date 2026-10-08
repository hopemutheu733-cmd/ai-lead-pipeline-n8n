# AI Lead Pipeline (n8n + Supabase + LLM)

An automated lead intake pipeline. A lead is submitted to a webhook, validated, checked against a database for duplicates, scored by an LLM, saved to Supabase, and answered with a structured response. A second workflow emails a daily summary of new leads, and a third logs any failure.

![AI Lead Pipeline workflow](Lead%20Pipeline%20.png)

## How it works

1. **Webhook** receives a lead (name, email, company, message).
2. **Email validation** rejects missing or malformed emails (HTTP 400).
3. **Duplicate check** looks the email up in Supabase and rejects repeats (HTTP 409).
4. **AI scoring** (OpenRouter LLM with a structured output parser) returns a score from 1 to 10, a category (hot, warm or cold) and a one-sentence reason.
5. **Save** writes the lead and its score to a Supabase `leads` table.
6. **Response** returns JSON with the status, score and category (HTTP 200).

<img width="600" height="270" alt=" Lead Table.png " src="https://github.com/user-attachments/assets/b6f0b76c-9a92-4b22-bd55-cf38288506ea" />

## Reliability

- Retries (3 tries, 2 seconds apart) on the database lookup, the AI step and the save step.
- A separate error workflow logs failures (workflow name, failing node and error message) to an `errors` table.
- Row Level Security is enabled on both tables, and n8n connects with a service role key, so the tables are not exposed through the public API.
- A unique constraint on `email` backs up the duplicate check at the database level.

## Daily summary

A scheduled workflow runs at 8am (Africa/Nairobi), reads the last 24 hours of leads, calculates the total, average score and hot/warm/cold counts, lists the top 3 leads, and emails the report.

## Stack

n8n cloud, Supabase (Postgres), OpenRouter (LLM), Gmail.

## Database

- `leads`: id, email (unique), name, company, message, score, category, score_reason, status, created_at
- `errors`: id, workflow_name, node_name, error_message, payload, created_at

The full schema is in `schema.sql`.

## Workflows

| File | Purpose |
| --- | --- |
| `Workflows/lead-pipeline.json` | Main intake, scoring and save workflow |
| `Workflows/daily-summary.json` | Scheduled email report |
| `Workflows/error-handler.json` | Logs failures to the `errors` table |

## Example request

```powershell
Invoke-RestMethod -Method Post -Uri "<your-n8n-url>/webhook/lead-pipeline" -ContentType "application/json" -Body '{"name":"Daniel Kamau","email":"daniel@example.com","company":"Savanna Freight","message":"Looking for help automating dispatch reports."}'
```

## Responses

| Case | Status | Body |
| --- | --- | --- |
| New valid lead | 200 | status: success, score, category |
| Invalid or missing email | 400 | status: error |
| Existing email | 409 | status: duplicate |

## Tested

- New lead end to end through the production URL
- Duplicate lead rejection (HTTP 409)
- Invalid email rejection (HTTP 400)
- Forced failure in the save step, confirming the error is caught and logged by the error workflow

## What I learned

- Supabase tables created without automatic API exposure need explicit grants for the service role.
- Date filters sent to Supabase should be in UTC.
- Error workflows only fire on published, production runs, not on test executions in the editor.

## Setup

1. Create a Supabase project and run `schema.sql` in the SQL Editor.
2. Import the three workflow files from the `Workflows` folder into n8n.
3. Create credentials for Supabase (service role key), OpenRouter and Gmail, and connect them to the matching nodes.
4. Set the error workflow in the main workflow's settings, then publish all three.
