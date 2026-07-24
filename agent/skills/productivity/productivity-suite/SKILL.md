---
name: productivity-suite
description: "Class-level productivity integrations: Airtable, Google Workspace, Linear, Notion, maps, PDFs/OCR, PowerPoint, and Teams meeting pipelines."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Productivity, Documents, Tasks, Google-Workspace, Notion, Linear, Airtable, PDF, Meetings]
---

# Productivity Suite

Use this umbrella when the user asks to manipulate productivity systems, documents, tasks, calendars, records, maps, slide decks, OCR/PDFs, or meeting summaries.

## SaaS/work management integrations

- Airtable: REST record CRUD, filters, upserts.
- Linear: issue/project/team management through GraphQL.
- Notion: pages, databases, markdown import/export, and API/CLI workflows.
- Google Workspace: Gmail, Calendar, Drive, Docs, and Sheets via `gws` or Python helpers.

Always verify credentials and target workspace/base/team before writing. For destructive or broad operations, show the plan and limit scope.

## Documents and files

- OCR/documents: extract text from PDFs and scans with PyMuPDF, marker-pdf, or similar.
- Nano PDF: targeted PDF text/title typo edits through nano-pdf.
- PowerPoint: create, read, edit, and validate `.pptx` decks, slides, notes, and templates. Preserve the package's scripts/schemas if doing serious deck manipulation.
- Obsidian/note vaults: read/search/create/edit markdown notes through resolved concrete vault paths, using file tools rather than shell text hacks. The archived `obsidian` package contains the vault-path convention, wikilink rules, and append/edit patterns.

## Meetings and communication pipelines

Use the Teams meeting pipeline for meeting summary operations, status inspection, replaying jobs, and Microsoft Graph subscription management. The archived `teams-meeting-pipeline` package contains the full `hermes teams-pipeline` command reference, Graph subscription renewal pitfalls, required `MSGRAPH_*` env vars, and troubleshooting decision tree; restore/re-home it if serious Teams pipeline operations need exact command syntax.

## Slide decks and presentations

For `.pptx` work, treat PowerPoint as part of this productivity umbrella. The archived `powerpoint` package contains substantial scripts and references for deck extraction, template editing, PPTXGenJS creation, thumbnail/visual QA, and office XML manipulation. Restore or re-home the package before doing non-trivial deck editing rather than flattening only its SKILL.md.

## Maps and places

Use maps workflows for geocoding, POI lookup, routes, and timezones through OpenStreetMap/OSRM-style services. Be explicit about units, locale, and whether results are approximate.

## Verification

For every write, return an object ID, URL, file path, or command output proving the change. For reads, cite the source system and filters used.
