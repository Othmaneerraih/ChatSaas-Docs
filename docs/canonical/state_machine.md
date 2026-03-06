> ⚠️ Canonical Spec File — Read-Only. Modify only through canonical-first change control.

# Conversation State Machine

Every conversation has two state dimensions: status (lifecycle) and mode (who’s responding).

## 6.1 Status Transitions

| From | To | Trigger |
| --- | --- | --- |
| (new) | active | First customer message received |
| active | escalated | Agent calls escalate_to_human OR merchant clicks Take Over |
| escalated | active | Merchant clicks Release |
| active | resolved | Merchant marks resolved OR 24h inactivity with no pending order |
| active | abandoned | 72h inactivity |
| escalated | resolved | Merchant marks resolved |
| resolved | active | Customer sends new message |
## 6.2 Mode Transitions

| From | To | Trigger | Effect |
| --- | --- | --- | --- |
| ai | manual | Merchant clicks Take Over | AI stops responding. Merchant types directly. |
| manual | ai | Merchant clicks Release | AI resumes. Gets conversation summary. |
| ai | ai_whisper | Merchant enters conversation view while AI active | AI keeps responding. Suggested responses shown in sidebar. |
| ai_whisper | manual | Merchant clicks Take Over | AI pauses. Merchant types. |
| manual | ai_whisper | Not allowed | Must Release to AI first, then re-enter. |
## 6.3 Cart State Transitions

| State | Allowed Operations | Guard |
| --- | --- | --- |
| empty | add_to_cart | Product must exist in tenant catalog |
| has_items | add_to_cart, remove_from_cart, calculate_total | Max 50 items, max qty 99 each |
| summary_shown | confirm, modify, abandon | calculate_total has been called |
| confirmed | create_order | confirm_state = true. Can only be set by explicit customer confirmation. |
| order_created | get_order_status | Cart is reset. New cart starts empty. |

<!-- Rationale note (Aidy_Technical_Spec_v3.docx §2.3): v3 emphasizes explicit confirmation and idempotency gates in the cart→order flow. -->
