---
agent: agent
---

Transform and refactor all existing documentation and informational files so they are clearly organized into a logical folder structure, grouped by their content and the issues or topics they address. Follow the rules and steps below:

1. Scope and discovery
   - Scan the repository for all documentation and informational files (for example: `.md`, `.txt`, `.pdf` where text is extractable).
   - Extract for each file: filename, current path, title or main heading, short summary of content, and any obvious tags (e.g., “architecture”, “API”, “frontend”, “AI context”, “deployment”, “testing”, “troubleshooting”).

2. Content analysis and grouping
   - Analyze each document’s content to determine its primary purpose and topic (for example: architecture overview, domain model, API integration, environment config, troubleshooting, how-to guides, AI prompt context, onboarding, etc.).
   - Identify the main “issue” or concern each document tackles (for example: performance problem, bug class, deployment procedure, specific feature specification, testing strategy, AI agent guidance).
   - Assign one or more high-level categories per document, such as (examples, adapt as needed):
     - `architecture/` (high-level design, modules, patterns, data flow)
     - `frontend/` (UI structure, state management, widgets, navigation)
     - `backend/` (APIs, database, RPCs, services)
     - `ai_context/` (AI agent context files, prompt guidance, model-facing docs)
     - `dev_process/` (CI/CD, branching, release, versioning)
     - `testing/` (test strategy, frameworks, coverage, examples)
     - `ops_and_deployment/` (environments, infrastructure, hosting, monitoring)
     - `troubleshooting_and_known_issues/` (bug classes, fixes, workarounds)
     - `product_docs/` (user-facing guides, FAQs, feature descriptions)
     - `onboarding/` (new developer introductions, project overviews, quickstarts).

3. Target folder structure
   - Propose or use an explicit folder tree under a root docs directory, for example:
     - `docs/architecture/`
     - `docs/frontend/`
     - `docs/backend/`
     - `docs/ai_context/`
     - `docs/dev_process/`
     - `docs/testing/`
     - `docs/ops_and_deployment/`
     - `docs/troubleshooting_and_known_issues/`
     - `docs/product_docs/`
     - `docs/onboarding/`
   - If existing folders already follow a similar structure, reuse and extend them rather than creating duplicates.
   - For each document, decide its primary destination folder based on the dominant topic and the main issue it tackles. If a document clearly spans multiple domains, choose the best primary folder and consider creating short “index” or “link” stubs in secondary locations if needed (with references to the primary file).

4. File refactor rules
   - Move each documentation file into its chosen folder without changing its core technical content.
   - Normalize filenames to be:
     - Lowercase with words separated by hyphens.
     - Descriptive of the main topic and/or issue, for example:
       - `vr-app-manager-technical-analysis.md`
       - `architecture-high-level-overview.md`
       - `incident-report-system-troubleshooting.md`
       - `deployment-environments-and-config.md`.
   - If a file mixes multiple unrelated concerns (for example: architecture plus troubleshooting plus onboarding), split it into separate files when safe, placing each new file in the correct folder.
   - Ensure all intra-doc links and references are updated to reflect new paths and filenames.

5. Grouping by issue/problem
   - Within `docs/troubleshooting_and_known_issues/`, group files by the specific issues they tackle (for example: login/authentication issues, caching problems, performance bottlenecks, deployment failures, test flakes).
   - Within feature-specific or architecture folders, group or tag documents by the main problem or topic (for example: machines overview performance, cache invalidation rules, mobile web constraints).
   - If helpful, create short index/overview files that list documents by issue category, linking to each detailed doc.

6. AI-context and info-file focus
   - Pay special attention to large AI-context and technical-analysis files (for example, project-wide AI context documents) and move them into a dedicated `docs/ai_context/` folder.
   - Ensure those AI-context files are clearly labeled and easy for AI agents to consume (for example: one file per project or domain, with stable filenames and headings).
   - Where possible, extract highly reusable sections (e.g., “AI prompt guidance”, “project constraints”, “coding standards”) into separate, focused AI context files and place them under `docs/ai_context/`.

7. Output and reporting
   - Produce a machine-readable summary (for example, JSON or markdown table) describing, for every processed document:
     - Original path and filename.
     - New path and filename.
     - Detected primary category and any secondary categories.
     - Short description (1–2 sentences) of the document’s content and the issue it tackles.
   - Ensure the final documentation tree is consistent, with no orphaned or duplicate docs, and can be used directly as a clean, organized knowledge base for both humans and AI agents.
