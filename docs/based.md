# Based

Based is the language for building conversational flows on the Brainbase platform. It's Python with a small set of constructs for managing multi-turn, LLM-driven conversations.

If you can write Python, you can write Based. The additions are:

- `loop:` / `until:` — define conversation loops where the LLM routes to the right handler
- `talk()` — call the LLM with a prompt and a set of conditions
- `say()` — send a message to the user directly (no LLM)
- `.ask()` — extract structured data from a conversation response
- `extract()` — save structured data to deployment logs
- `done()` — end execution

Deployment-specific functions (injected per channel, not core Based):
- `transfer()`, `end_call()` — available in voice deployments
- `send_sms()` — available when SMS is configured

Everything else is standard Python — variables, functions, imports, control flow, API calls.

> For the full official reference, see the [Based Language Fundamentals](https://docs.usebrainbase.com/language-fundamentals/overview) documentation.

---

## Core pattern: loop / until

The fundamental Based pattern is a conversation loop. The LLM talks to the user, and when a condition is met, execution branches to the matching handler.

```python
loop:
    res = talk("You are a helpful receptionist. Help the caller with their request.", False)
until "caller wants to schedule an appointment":
    say("Let me connect you with scheduling.")
until "caller wants to check order status":
    order_id = res.ask(question="What is the order ID?", example={"order_id": "ORD-12345"})
    # look up order, respond...
until "caller wants to end the conversation":
    say("Thanks for calling. Goodbye!")
```

**How it works:**

1. `talk()` sends the prompt + conversation history to the LLM
2. Each `until` condition is registered as a possible action
3. When the LLM determines a condition is met, execution branches to that `until` block
4. After the block executes, the flow ends (unless you `return` to loop again)

The string in `until "..."` is a natural language description. The LLM decides when it applies. Write conditions that are clear and unambiguous.

### The `talk()` function

```python
res = talk("System prompt describing the agent's behavior.", False)
```

`talk()` takes two positional arguments:

| Argument | Type | Description |
|-|-|-|
| prompt | `str` | System prompt for the LLM. Describes the agent's role, personality, and instructions. |
| first | `bool` | Controls turn-taking. `True` = AI speaks first (generates a response immediately). `False` = AI waits for the user to speak first. |

`talk()` returns a result object. Its primary use is calling `.ask()` to extract structured data from the conversation. The engine handles routing to the correct `until` block automatically — you don't need to inspect the result for branching.

The prompt is the system message. It persists across the conversation — you don't need to repeat context. The LLM sees the full message history automatically.

### Condition types

**String conditions** — natural language descriptions that the LLM matches against:

```python
until "user wants to schedule a meeting":
    # handle scheduling
until "user asks about pricing":
    # handle pricing
until "user says goodbye":
    # handle farewell
```

**Tool schema conditions** — explicit function schemas for structured extraction:

```python
schedule_tool = {
    "name": "schedule_meeting",
    "description": "Schedule a meeting for the user",
    "parameters": {
        "type": "object",
        "properties": {
            "date": {"type": "string", "description": "Meeting date"},
            "time": {"type": "string", "description": "Meeting time"},
            "attendees": {"type": "array", "items": {"type": "string"}, "description": "List of attendees"}
        },
        "required": ["date", "time"]
    }
}

loop:
    res = talk("Help the user schedule meetings.", False)
until schedule_tool as meeting:
    # meeting = {"date": "2024-03-15", "time": "2pm", "attendees": ["Alice"]}
    print(meeting)
    say(f"Meeting scheduled for {meeting['date']} at {meeting['time']}.")
until "user says goodbye":
    say("Goodbye!")
```

Use `as variable` to capture the extracted arguments. The schema follows a standard function calling format. You can also use a simplified format:

```python
# Simplified — just name, description, parameters
tool = {"name": "...", "description": "...", "parameters": {...}}

# Full format — also works
tool = {"type": "function", "function": {"name": "...", "description": "...", "parameters": {...}}}
```

**When to use which:**
- String conditions: for routing and branching decisions ("user wants X", "caller asks about Y")
- Tool schema conditions: when you need the LLM to extract specific structured data as part of the condition match

---

## Extracting data with `.ask()`

`.ask()` is the primary way to extract structured information from a conversation. Call it on any object — typically the `talk()` response.

```python
res = talk("You are a car sales agent. Help customers find cars.", False)

# Extract structured data from the conversation
contact = res.ask(
    question="Did the customer share contact information?",
    example={"name": "John Smith", "phone": "555-1234", "email": "john@example.com"}
)

# contact = {"name": "Jane Doe", "phone": "555-9876", "email": None}
```

**Parameters:**

| Parameter | Type | Description |
|-|-|-|
| `question` | `str` | What to extract from the conversation context |
| `example` | `dict`, `list`, `str` | An example of the expected output shape. The schema is inferred from this. |
| `schema` | `dict` (optional) | Explicit JSON schema for the output. Overrides `example` if both are provided. |

The `example` parameter is the most common way to define the expected shape. The LLM will return data matching that structure.

```python
# Extract a simple value
name = res.ask(question="What is the customer's name?", example={"name": "John"})

# Extract a list
items = res.ask(question="What items did they order?",
    example={"items": [{"name": "tacos", "quantity": 2}]})

# Extract from a dict (not just from talk responses)
car = {"make": "Toyota", "model": "Camry", "year": 2024, "price": 28500}
highlights = car.ask(
    question="What are this car's selling points?",
    example=["reliable", "good price", "recent model year"]
)
```

**Chaining:** You can chain `.ask()` calls for multi-step extraction:

```python
res = talk("Collect the customer's shipping details.", False)
address = res.ask(question="What address did they provide?",
    example={"street": "123 Main St", "city": "Austin", "state": "TX", "zip": "78701"})
validation = address.ask(question="Is this a complete US address?",
    example={"complete": True, "missing_fields": []})
```

---

## Built-in functions

These are always available in any Based flow, regardless of deployment type.

### `say(message, exact=True)`

Send a message directly to the user without calling the LLM. By default, the message is output verbatim (`exact=True`). Pass `exact=False` to allow the AI to rephrase while maintaining meaning.

```python
say("Thanks for calling! Let me look that up for you.")
say("Your order total is $42.50.")

# exact=False lets the AI rephrase the message naturally
say("Inform the user their order has been placed successfully.", exact=False)
```

### `done()`

Stop execution. The session state is saved — if the user sends another message, execution resumes.

```python
if not order_valid:
    say("Sorry, we couldn't process that order.")
    done()
```

### `extract(key, value)`

Save structured data as a runtime extraction on the deployment log. Use this when you already have the data in a variable — no need for AI to re-extract it from the transcript.

```python
# Save simple values
extract("customer_name", name)
extract("order_total", 42.99)

# Save structured data
extract("shipping_address", {
    "street": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "zip": "94102"
})

# Common pattern: extract with .ask() then save
order = res.ask(
    question="What did the customer order?",
    example={"items": [{"name": "latte", "quantity": 1}], "total": 5.50}
)
extract("order_details", order)
```

Keys cannot start with `_` (reserved for internal use). Values must be JSON-serializable.

### `print()`

Debug output. Appears in session traces and the studio console, not in the user-facing conversation.

```python
print(f"[DEBUG] Customer info: {customer_info}")
print(f"[DEBUG] API response: {response.status_code}")
```

---

## Deployment-specific functions

These functions are injected by the deployment layer and are only available in certain deployment types. They are not core Based — they're provided by the service handling the channel.

### Voice deployments

#### `transfer(phone_number)` / `transfer(phone_number, extension)` / `transfer(phone_number, options)`

Transfer the current call to another phone number.

```python
# Basic transfer
transfer("+15551234567")

# Transfer with extension (dials after connection, 1s default pause)
transfer("+15551234567", "271")

# Transfer with custom pause before extension
transfer("+15559876543", {"extension": "221", "pauseSeconds": 2})
```

#### `end_call()`

Hang up the call.

```python
say("Thanks for calling. Goodbye!")
end_call()
```

### SMS-enabled deployments

#### `send_sms(from_number, to, content)`

Send an SMS message. The `from_number` must be from your phone number library.

```python
result = await send_sms(
    from_number="+15551234567",
    to="+15559876543",
    content="Your appointment is confirmed for tomorrow at 2pm."
)
if result.success:
    say("I've sent you a confirmation text.")
elif result.status == "skipped":
    print(f"SMS skipped: {result.error}")
```

---

## Third-party integrations

Based provides an `integrations` client for connecting to third-party services configured in your Brainbase workspace. Integrations must be connected in the dashboard before they can be used.

```python
# Send a Slack notification
result = await integrations.slack.send_message(
    channel="#notifications",
    text=f"New order received: {order_id}"
)

# Send email via Gmail
result = await integrations.gmail.send_email(
    to="user@example.com",
    subject="Order Confirmation",
    body=f"Your order #{order_id} has been confirmed!"
)
```

The pattern is `integrations.<app_name>.<action_name>(...)`. Available integrations depend on what's connected in your workspace.

---

## Variables and state

### Regular variables

Variables assigned in your flow persist across conversation turns. You can use any Python data type.

```python
order_items = []
customer_name = None

loop:
    res = talk("Take the customer's order.", False)
until "customer adds an item":
    item = res.ask(question="What did they add?", example={"name": "tacos", "qty": 2})
    order_items.append(item)
    say(f"Added {item['qty']}x {item['name']}. Anything else?")
    return  # go back to loop
until "customer is done ordering":
    say(f"Your order has {len(order_items)} items. Let me calculate the total.")
```

### The `state` dict

The `state` dict contains session metadata. In voice deployments, it includes caller information:

```python
caller_number = state.get('Caller', '')  # E.164 format: +15551234567
```

In outbound campaigns, `state` contains campaign data set when the call was initiated:

```python
customer_name = state.get('customer_name', 'there')
appointment_date = state.get('appointment_date', '')
```

### Flow variables

Flow variables are configured in the Brainbase dashboard and accessed via `variables`:

```python
business_name = variables.get('business_name', 'our company')
hours = variables.get('hours_of_operation', 'Monday through Friday, 9am to 5pm')

loop:
    res = talk(f"You are an assistant for {business_name}. Our hours are {hours}.", False)
```

Flow variables are the primary mechanism for templatizing flows — write one flow, deploy it many times with different variables per deployment.

---

## Making API calls

### Using `requests` (recommended)

```python
import requests

try:
    response = requests.post(
        "https://api.example.com/orders",
        json={"items": order_items, "customer": customer_info}
    )
    if response.ok:
        order_id = response.json().get("id")
        say(f"Your order {order_id} has been placed!")
    else:
        say("There was an issue placing your order. Let me try again.")
except Exception as e:
    say("I'm having trouble connecting to our system. Please try again shortly.")
```

Always wrap API calls in `try/except`. Network failures should never crash the flow.

### Using `api` (legacy, deprecated)

The `api.get_req()` and `api.post_req()` helpers still work but are deprecated. Prefer `requests`.

```python
# Deprecated — use requests.get() instead
response = api.get_req(url="https://api.example.com/status", headers={...})

# Deprecated — use requests.post() instead
response = api.post_req(url="https://api.example.com/data", headers={...}, body={...})
```

---

## Async functions

Based supports `async def` and `await` for organizing complex flows:

```python
async def collect_contact_info(response):
    contact = response.ask(
        question="What contact info did the customer share?",
        example={"name": "John", "phone": "555-1234", "email": "john@example.com"}
    )
    return contact

async def check_availability(date, time):
    try:
        result = requests.get(f"https://api.example.com/slots?date={date}&time={time}")
        return result.json().get("available", False)
    except:
        return False

loop:
    res = talk("Help the customer book an appointment.", False)
until "customer wants to book":
    contact = await collect_contact_info(res)
    schedule = res.ask(question="When do they want to come in?",
        example={"date": "Saturday", "time": "2pm"})
    available = await check_availability(schedule["date"], schedule["time"])
    if available:
        say(f"You're all set for {schedule['date']} at {schedule['time']}!")
    else:
        say("That slot isn't available. Would you like to try a different time?")
        return  # back to loop
```

---

## Nested loops

Flows can have nested `loop/until` blocks for multi-phase conversations:

```python
say("Welcome! How can I help you today?")

loop:
    res = talk("Determine if the caller needs sales, service, or something else.", False)
until "caller needs sales":
    say("I can help with that.")
    loop:
        res = talk("You are a sales assistant. Help the customer find what they need.", False)
    until "customer wants to schedule a test drive":
        contact = res.ask(question="Get their contact info.", example={"name": "John", "phone": "555-1234"})
        say(f"Great, {contact['name']}! We'll see you soon.")
    until "customer wants pricing":
        say("I can help with that. Which model are you interested in?")
        return  # stay in sales loop
until "caller needs service":
    say("Let me get you to the right person.")
    # handle service routing...
```

---

## The `return` statement

`return` inside an `until` block sends execution back to the enclosing `loop`. Use it when the conversation should continue after handling a condition.

```python
loop:
    res = talk("Take the customer's food order.", False)
until "customer adds an item":
    item = res.ask(question="What did they order?", example={"name": "tacos", "quantity": 2})
    order.append(item)
    say(f"Added. Anything else?")
    return  # <-- back to loop, keeps taking orders
until "customer is done":
    say(f"Got it. Your total is ${calculate_total(order):.2f}.")
```

Without `return`, the flow ends after an `until` block executes.

---

## Patterns and best practices

### Prompt design

The prompt in `talk()` is the most important part of your flow. Good prompts:

- **Define the agent's identity clearly.** Name, role, company, personality.
- **Are specific about behavior.** "Ask for their name before proceeding" not "collect information."
- **Include relevant context.** Business hours, menu items, available services — put reference data directly in the prompt.
- **Set boundaries.** "Do not discuss topics outside of scheduling" prevents drift.

```python
# Good: specific, contextual, bounded
PROMPT = """
You are Alex, the front desk assistant at Riverside Dental.
Your job is to help callers schedule, reschedule, or cancel appointments.

Available services: cleaning, filling, crown, root canal, consultation.
Hours: Monday-Friday 8am-5pm, Saturday 9am-1pm, closed Sunday.

Be warm and professional. If a caller asks about something outside
scheduling (billing, insurance, complaints), let them know you'll
transfer them to the right department.
"""

# Bad: vague, no personality, no bounds
PROMPT = "You are a dental office assistant. Help the caller."
```

### Condition design

Write `until` conditions that are mutually exclusive and comprehensive:

```python
# Good: clear, distinct, covers the space
until "caller wants to schedule a new appointment":
until "caller wants to reschedule an existing appointment":
until "caller wants to cancel an appointment":
until "caller has a question about their upcoming appointment":
until "caller needs something else or wants to speak to a person":

# Bad: overlapping, ambiguous
until "caller wants an appointment":      # schedule? reschedule? cancel?
until "caller is done":                    # too vague
```

### Error handling for API calls

```python
try:
    response = requests.post(CRM_URL, json=payload, headers=headers)
    if response.ok:
        say("I've updated your record.")
    else:
        say("I wasn't able to update our system, but I've noted your information.")
except Exception as e:
    say("I'm having trouble reaching our system right now.")
    # flow continues — don't let API failures kill the conversation
```

### Using `return` for multi-step collection

When you need to collect multiple pieces of information across several turns:

```python
collected = {}

loop:
    res = talk("Collect the customer's shipping address. Ask for each field one at a time.", False)
until "customer provides address info":
    info = res.ask(question="What address info did they provide?",
        example={"street": "123 Main St", "city": "Austin", "state": "TX", "zip": "78701"})
    collected.update({k: v for k, v in info.items() if v})
    missing = [f for f in ["street", "city", "state", "zip"] if f not in collected]
    if missing:
        say(f"Got it. I still need your {', '.join(missing)}.")
        return  # back to loop
    say("Thanks, I have your full address.")
until "customer wants to stop or go back":
    say("No problem.")
```

### Templatizing with flow variables

Write one flow, deploy it across many instances using `variables`:

```python
name = variables.get('agent_name', 'Assistant')
company = variables.get('company_name', 'our company')
greeting = variables.get('greeting', f'Thank you for calling {company}.')
hours = variables.get('hours_of_operation', '9am to 5pm, Monday through Friday')

say(greeting)

loop:
    res = talk(f"""You are {name}, an AI assistant for {company}.
Hours of operation: {hours}.
Help callers with their requests. Be professional and concise.""", False)
until "caller has a question about hours":
    say(f"We're open {hours}.")
    return
```

### Voice-specific considerations

For voice deployments, keep these in mind:

- **`say()` is spoken aloud.** Write naturally — avoid URLs, special characters, and abbreviations the TTS won't handle well.
- **`say()` defaults to `exact=True`** (verbatim output). This is usually what you want for voice. Use `exact=False` only when you want the AI to rephrase.
- **`time.sleep(seconds)`** adds a pause. Useful before transfers or after long responses.
- **Phone numbers in speech:** Format as individual digits: `"five five five, one two three four"`.
- **Keep responses concise.** Long agent responses feel unnatural in voice. Aim for 1-3 sentences.

---

## Common flow shapes

### IVR / Call router

Route callers to the right department or person:

```python
say("Thank you for calling Acme Corp. How can I direct your call?")
loop:
    res = talk("Route the caller to the right department. Ask clarifying questions if needed.", False)
until "caller needs sales":
    transfer(variables.get('sales_number'))
until "caller needs support":
    transfer(variables.get('support_number'))
until "caller needs billing":
    transfer(variables.get('billing_number'))
until "caller asks for a specific person":
    person = res.ask(question="Who do they want to reach?", example={"name": "John Smith"})
    # look up in directory...
```

### Data collection with confirmation

Collect information, confirm it, then act:

```python
loop:
    res = talk("Collect the caller's appointment details: date, time, and service needed.", False)
until "caller has provided all details":
    details = res.ask(question="What are the appointment details?",
        example={"date": "March 15", "time": "2pm", "service": "cleaning"})
    extract("appointment_details", details)
    say(f"Just to confirm — {details['service']} on {details['date']} at {details['time']}. Is that correct?")
    loop:
        res = talk("Confirm the appointment details with the caller.", False)
    until "caller confirms":
        requests.post(BOOKING_URL, json=details, headers=headers)
        say("You're all set!")
    until "caller wants to change something":
        say("No problem. What would you like to change?")
        return  # back to outer loop
```

### Order taking with running total

```python
import json

menu = variables.get('menu', '{}')
order = []

say("Welcome! What can I get for you today?")
loop:
    res = talk(f"Take the customer's order. Menu: {menu}", False)
until "customer adds an item":
    item = res.ask(question=f"What did they order? Match exactly to menu names. Menu: {menu}",
        example={"items": [{"name": "chicken tacos", "quantity": 2}]})
    order.extend(item.get("items", []))
    say(f"Added. Your order has {len(order)} items so far. Anything else?")
    return
until "customer is done ordering":
    extract("final_order", order)
    say("Let me ring that up for you.")
    # submit order to POS...
until "customer wants to remove an item":
    removal = res.ask(question="Which item do they want to remove?", example={"name": "chicken tacos"})
    order = [i for i in order if i["name"] != removal.get("name")]
    say(f"Removed. You now have {len(order)} items. Anything else?")
    return
```

---

## Debugging

### Tracing

Reason tracing is a deployment-level setting (not a `talk()` argument). When enabled, the LLM must explain *why* it matched a condition. These reasons are recorded as trace events in the session and visible in deployment logs. It's configured per-deployment, not in your Based code.

### Common issues

| Issue | Cause | Fix |
|-|-|-|
| Flow exits unexpectedly | No `until` condition matched | Add a catch-all condition or make existing conditions broader |
| LLM picks wrong condition | Conditions are ambiguous or overlapping | Make conditions more specific and mutually exclusive |
| Variables lost between turns | Variable defined inside a function (local scope) | Define at top level or in the main flow body |
| API call crashes the flow | Uncaught exception | Wrap in `try/except` |
| `.ask()` returns unexpected shape | Example doesn't match the desired structure | Refine the `example` parameter to be more explicit |

---

## Known limitations

Based is powerful but has constraints you should understand:

### Based constructs must live at the top level

In v2, `loop:`, `until:`, and `talk()` constructs must exist at the top level of your script or inside other `loop/until` blocks. **They cannot be placed inside regular Python functions.** The engine needs to pause and resume execution at each `talk()` boundary, so the conversation structure must be defined at the top level.

This means you can't do:

```python
# THIS DOES NOT WORK in v2
def handle_sales():
    loop:
        res = talk("Help the customer with sales.", False)
    until "customer wants to buy":
        say("Great!")

handle_sales()  # won't work — Based constructs can't be inside functions
```

Instead, use nested `loop/until` blocks inline:

```python
# This works — Based constructs at top level
loop:
    res = talk("Route the caller.", False)
until "caller needs sales":
    # Nest the sales conversation directly
    loop:
        res = talk("Help the customer with sales.", False)
    until "customer wants to buy":
        say("Great!")
```

You can still use regular Python functions for helper logic (API calls, data processing, etc.) — just keep the `loop/until/talk` structure at the top level. `async def` functions with `.ask()` calls work fine.

### Don't put inline comments after `return`

The Based converter doesn't handle `return  # comment` correctly — the comment gets treated as a return value and produces a syntax error. Put the comment on a separate line instead.

```python
# BAD — will break the converter
    return  # go back to loop

# GOOD
    # go back to loop
    return
```

### `.ask()` is a separate LLM call

Each `.ask()` invocation makes an independent LLM call for data extraction. It doesn't share context with the main `talk()` conversation. This means:

- It only sees the data you pass to it (the object it's called on), not the full conversation history
- Multiple `.ask()` calls add latency — batch extractions when possible

```python
# Less efficient — two LLM calls
name = res.ask(question="What is their name?", example={"name": "John"})
phone = res.ask(question="What is their phone?", example={"phone": "555-1234"})

# More efficient — one LLM call
contact = res.ask(question="What is their name and phone?",
    example={"name": "John", "phone": "555-1234"})
```

### No explicit flow-to-flow handoff

There's no built-in mechanism to jump between different Based flows within the same session. Each deployment runs a single flow. For multi-flow architectures, use nested `loop/until` blocks within one flow, or use separate deployments with call transfers.

### Condition matching is LLM-dependent

The LLM decides which `until` condition matches. This means:
- Conditions that are too similar may cause inconsistent routing
- Very short or vague conditions give the LLM less signal to work with
- Different models may match conditions differently — test when switching models

---

## V1 engine note

The v2 Based engine is the current standard. A legacy v1 engine also exists. The syntax described in this document is for v2. V1 flows use similar constructs but run on a different runtime with some behavioral differences. New flows should always target v2.

If you're working with an existing v1 agent and need guidance, contact the Brainbase team at abhinav@brainbaselabs.com.
