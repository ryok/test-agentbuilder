# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Python project demonstrating an AI agent workflow system using the `agents` library (appears to be an OpenAI-based agent framework). The project implements a conversational agent that processes email input and generates reply text.

## Core Architecture

### Agent Workflow Pattern

The codebase follows an async workflow pattern centered around:

1. **Agent Definition** (`sample.py:5-16`): Agents are configured with:
   - `name`: Agent identifier
   - `instructions`: Task description (currently in Japanese)
   - `model`: LLM model to use (e.g., "gpt-5")
   - `model_settings`: Configuration including store, reasoning effort, and summary settings

2. **Workflow Execution** (`sample.py:28-66`):
   - Uses `trace()` context manager for observability
   - Maintains `conversation_history` as list of `TResponseInputItem` objects
   - Implements approval gate pattern via `approval_request()` function
   - Executes agent via `Runner.run()` with input history and trace metadata
   - Extends conversation history with agent responses using `to_input_item()`
   - Extracts final output using `final_output_as(str)`

3. **Input/Output Pattern**:
   - Input: Structured as Pydantic `BaseModel` (`WorkflowInput`)
   - Conversation items use specific schema with `role` and `content` array containing `type: "input_text"` objects
   - Output: Extracted from agent result and structured as dict

## Python Environment Setup

This project uses **uv** for Python environment and dependency management.

### Initial Setup

```bash
# Create virtual environment and install dependencies
uv sync

# Or create a new venv if needed
uv venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

### Installing Dependencies

```bash
# Add a new dependency
uv add <package-name>

# Add a dev dependency
uv add --dev <package-name>

# Install from pyproject.toml
uv sync
```

### Running Python Scripts

```bash
# Run with uv (automatically uses the project's venv)
uv run python sample.py

# Or run any Python command
uv run python -c "import asyncio; from sample import run_workflow, WorkflowInput; print(asyncio.run(run_workflow(WorkflowInput(input_as_text='test'))))"
```

## Development Commands

### Running the Workflow

```bash
# Using uv run
uv run python sample.py
```

Or programmatically:

```python
import asyncio
from sample import run_workflow, WorkflowInput

# Execute the workflow
result = asyncio.run(run_workflow(WorkflowInput(input_as_text="your email text here")))
```

## Key Implementation Details

- **Approval System**: The `approval_request()` function at line 19 is a placeholder (always returns True) and needs implementation for production use
- **Trace Metadata**: Workflow includes trace metadata with `__trace_source__` and `workflow_id` for tracking
- **Bilingual Context**: Instructions are in Japanese; plan accordingly when modifying agent behavior
- **State Management**: A `state` dict is initialized but currently unused (line 30-32) - likely for future stateful workflow extensions

## Adding New Agents

When adding agents to the workflow:
1. Define agent with `Agent()` constructor including name, instructions, model, and settings
2. Add agent execution point in `run_workflow()` after appropriate approval gate
3. Update `conversation_history` with agent results using `.extend([item.to_input_item() for item in result.new_items])`
4. Extract and structure final output as needed
