# AI Auto-Reply System - Implementation Plan

## Overview
Smart AI-powered auto-reply system for WhatsApp messages. Unlike generic chatbots, this will provide contextual, personalized responses based on conversation history and business context.

---

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  WhatsApp       │────▶│  Message Router  │────▶│  AI Engine      │
│  Service        │     │  (Filter/Queue)  │     │  (GPT/Claude)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │                        │
                                ▼                        ▼
                        ┌──────────────────┐     ┌─────────────────┐
                        │  Rules Engine    │     │  Context Store  │
                        │  (Who to reply)  │     │  (MongoDB)      │
                        └──────────────────┘     └─────────────────┘
```

---

## Core Features

### 1. Reply Modes
| Mode | Description | Use Case |
|------|-------------|----------|
| **All Chats** | Reply to every incoming message | Personal assistant |
| **Selected Contacts** | Only reply to specific contacts | VIP customer support |
| **Selected Groups** | Only reply in specific groups | Community management |
| **Business Hours Only** | Auto-reply outside hours | After-hours support |
| **Keyword Triggered** | Reply when keywords detected | FAQ handling |

### 2. Smart Context Features
- **Conversation Memory**: Remember last N messages per chat
- **Contact Context**: Custom instructions per contact (e.g., "This is a vendor, be professional")
- **Business Context**: Company info, products, FAQs fed to AI
- **Tone Matching**: Detect and match the sender's communication style

### 3. Safety & Control
- **Approval Queue**: Review AI responses before sending (optional)
- **Delay Timer**: Wait X seconds before auto-reply (looks natural)
- **Rate Limiting**: Max N auto-replies per hour per chat
- **Blacklist**: Never auto-reply to these contacts/groups
- **Human Takeover**: Detect when human should step in

---

## Database Schema

```javascript
// ai_settings collection
{
  enabled: Boolean,
  mode: "all" | "selected" | "keywords" | "business_hours",
  selected_contacts: [String],  // Phone numbers to auto-reply
  selected_groups: [String],    // Group IDs to auto-reply
  blacklist: [String],          // Never auto-reply to these
  business_hours: {
    enabled: Boolean,
    start: "09:00",
    end: "18:00",
    timezone: "America/New_York",
    outside_hours_message: "We'll get back to you..."
  },
  ai_config: {
    provider: "openai" | "anthropic" | "emergent",
    model: "gpt-4o" | "claude-3-sonnet",
    temperature: 0.7,
    max_tokens: 500,
    system_prompt: "You are a helpful assistant for...",
    business_context: "Company sells X, Y, Z...",
  },
  safety: {
    require_approval: Boolean,
    reply_delay_seconds: 5,
    max_replies_per_hour: 20,
    human_takeover_keywords: ["speak to human", "real person"]
  }
}

// conversation_context collection
{
  chat_id: String,
  contact_phone: String,
  messages: [
    { role: "user" | "assistant", content: String, timestamp: Date }
  ],
  contact_notes: String,  // Custom instructions for this contact
  last_human_reply: Date,  // Track when human last replied
  ai_paused: Boolean       // Human took over
}

// ai_response_queue collection (for approval mode)
{
  chat_id: String,
  incoming_message: String,
  proposed_response: String,
  status: "pending" | "approved" | "rejected" | "auto_sent",
  created_at: Date
}
```

---

## API Endpoints

```
POST   /api/ai/settings           - Update AI auto-reply settings
GET    /api/ai/settings           - Get current settings
POST   /api/ai/toggle             - Enable/disable AI replies
GET    /api/ai/queue              - Get pending responses for approval
POST   /api/ai/queue/:id/approve  - Approve and send response
POST   /api/ai/queue/:id/reject   - Reject response
POST   /api/ai/queue/:id/edit     - Edit and send response
GET    /api/ai/stats              - Get AI reply statistics
POST   /api/ai/test               - Test AI with a sample message
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create AI settings model and API
- [ ] Integrate with LLM provider (OpenAI/Anthropic via Emergent key)
- [ ] Basic message listener in WhatsApp service
- [ ] Simple reply to all incoming messages

### Phase 2: Smart Routing (Week 2)
- [ ] Implement reply modes (all/selected/keywords)
- [ ] Add contact/group filtering
- [ ] Add blacklist functionality
- [ ] Business hours detection

### Phase 3: Context & Memory (Week 3)
- [ ] Store conversation history per chat
- [ ] Implement context window (last N messages)
- [ ] Add business context injection
- [ ] Contact-specific instructions

### Phase 4: Safety & Control (Week 4)
- [ ] Approval queue system
- [ ] Rate limiting
- [ ] Human takeover detection
- [ ] Reply delay system

### Phase 5: UI & Polish (Week 5)
- [ ] Settings page in frontend
- [ ] Approval queue UI
- [ ] Statistics dashboard
- [ ] Test/preview functionality

---

## Message Flow

```
1. Incoming Message
   │
   ├─▶ Is AI enabled? ──No──▶ Ignore
   │
   ├─▶ Is sender blacklisted? ──Yes──▶ Ignore
   │
   ├─▶ Is within business hours? ──No──▶ Send outside-hours message
   │
   ├─▶ Does sender match filter? ──No──▶ Ignore
   │   (all / selected contacts / keywords)
   │
   ├─▶ Has human replied recently? ──Yes──▶ Pause AI (let human continue)
   │
   ├─▶ Build context (last N messages + business info)
   │
   ├─▶ Generate AI response
   │
   ├─▶ Approval required? ──Yes──▶ Add to queue
   │                              │
   │                              ▼
   │                        Wait for approval
   │
   └─▶ Wait delay ──▶ Send response ──▶ Log to history
```

---

## LLM Prompt Template

```
System: You are a helpful WhatsApp assistant for {business_name}.

Business Context:
{business_context}

Contact Info:
- Name: {contact_name}
- Notes: {contact_notes}

Conversation History:
{last_n_messages}

Instructions:
- Be helpful but concise (WhatsApp messages should be short)
- Match the sender's tone and language
- If you don't know something, say so
- For complex issues, suggest speaking to a human
- Never make up information about products/services

Respond to this message naturally:
"{incoming_message}"
```

---

## Cost Considerations

| Provider | Model | Cost per 1K tokens | Est. monthly (1000 msgs) |
|----------|-------|-------------------|-------------------------|
| OpenAI | GPT-4o | $0.005 in / $0.015 out | ~$15-20 |
| OpenAI | GPT-4o-mini | $0.00015 / $0.0006 | ~$1-2 |
| Anthropic | Claude 3 Sonnet | $0.003 / $0.015 | ~$12-15 |
| Anthropic | Claude 3 Haiku | $0.00025 / $0.00125 | ~$1-2 |

**Recommendation**: Start with GPT-4o-mini or Claude Haiku for cost efficiency, upgrade to full models for complex use cases.

---

## Security Considerations

1. **API Key Storage**: LLM API keys stored encrypted in MongoDB
2. **PII Handling**: Option to redact phone numbers before sending to LLM
3. **Response Filtering**: Block responses containing sensitive patterns
4. **Audit Logging**: Log all AI responses for review
5. **Kill Switch**: Instant disable via Telegram bot command

---

## Telegram Bot Integration

Add these commands to existing Telegram bot:
```
/ai on          - Enable AI auto-reply
/ai off         - Disable AI auto-reply
/ai status      - Show AI stats (msgs replied, queue size)
/ai queue       - Show pending approvals
/ai approve 123 - Approve response #123
/ai reject 123  - Reject response #123
```

---

## Questions to Decide Before Implementation

1. **LLM Provider**: OpenAI, Anthropic, or both options?
2. **Default Mode**: Start with "selected contacts" (safer) or "all"?
3. **Approval Default**: Should approval be required by default?
4. **Reply Delay**: What's the default delay? (5s recommended)
5. **Context Window**: How many messages to remember? (10-20 recommended)
6. **Group Support**: Should AI reply in groups or only DMs?

---

## Next Steps

1. Review and approve this plan
2. Decide on LLM provider (recommend starting with Emergent key for flexibility)
3. Prioritize which phase to start with
4. Set up test contacts for safe development

---

*Document Version: 1.0*
*Created: 2026-02-05*
*Status: Planning*
