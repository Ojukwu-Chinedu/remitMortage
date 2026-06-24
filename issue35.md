## Description
The end-to-end flow requires coordination between the escrow reaching its target, loan creation, and admin approval. The backend needs API routes to manage the full loan application lifecycle — from submission after escrow completion through admin review and on-chain loan creation.

**Branch:** `feat/loan-application-api`

**Example commits:**
- `feat(backend): add loan application routes with status tracking`
- `feat(backend): implement escrow completion check before loan submission`
- `feat(backend): add admin loan review endpoint with approve/reject actions`

## Scope & Tasks
1. **Application Routes (`src/routes/loan.ts`):**
   * `POST /api/loan/apply` — borrower submits a loan application. Validates that escrow target is met (queries the escrow contract via Soroban RPC). Creates application record in database with status `Pending`.
   * `GET /api/loan/:id` — returns application details and current status.
   * `GET /api/loan/borrower/:address` — returns all loan applications for a borrower.
2. **Admin Review Routes:**
   * `GET /api/loan/pending` — lists all pending applications for admin review.
   * `POST /api/loan/:id/approve` — admin approves the application. Triggers an on-chain `request_loan` + `approve_loan` call to the lending pool contract.
   * `POST /api/loan/:id/reject` — admin rejects with a reason.
3. **Status Transitions:** `Pending` → `Approved` / `Rejected` → `Disbursing` → `Repaying` → `Completed`.
4. **Wire to Express:** Register the new router in `src/index.ts`.

## Acceptance Criteria
- [ ] Loan application fails if escrow target is not met
- [ ] Application creates a database record with `Pending` status
- [ ] Admin approve triggers on-chain lending pool interaction
- [ ] Status transitions follow the defined lifecycle
- [ ] All endpoints return proper error responses for invalid states