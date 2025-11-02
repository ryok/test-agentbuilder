#!/usr/bin/env python
"""Test script for sample.py workflow"""
import asyncio
import os
from dotenv import load_dotenv
from sample import run_workflow, WorkflowInput

# Load environment variables from .env file
load_dotenv()

async def main():
    # Check if API key is available
    if not os.getenv("OPENAI_API_KEY"):
        print("Error: OPENAI_API_KEY not found in environment")
        return

    print("Testing workflow with sample email input...")

    # Create test input
    test_input = WorkflowInput(
        input_as_text="お世話になっております。明日の会議について確認したいことがあります。"
    )

    try:
        # Run the workflow
        result = await run_workflow(test_input)

        print("\n=== Workflow completed successfully ===")
        print(f"Result: {result}")

    except Exception as e:
        print(f"\n=== Error occurred ===")
        print(f"Error type: {type(e).__name__}")
        print(f"Error message: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
