#!/usr/bin/env python
"""FastAPI REST API wrapper for the email reply workflow"""
import os
import logging
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from dotenv import load_dotenv

from sample import run_workflow, WorkflowInput

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events"""
    # Startup
    logger.info("Starting email reply workflow API")

    # Verify OPENAI_API_KEY is set
    if not os.getenv("OPENAI_API_KEY"):
        logger.error("OPENAI_API_KEY environment variable is not set")
    else:
        logger.info("OPENAI_API_KEY is configured")

    yield

    # Shutdown
    logger.info("Shutting down email reply workflow API")


# Initialize FastAPI app
app = FastAPI(
    title="Email Reply Workflow API",
    description="AI-powered email reply generation using OpenAI Agents SDK",
    version="1.0.0",
    lifespan=lifespan
)


class WorkflowRequest(BaseModel):
    """Request model for workflow execution"""
    input_text: str = Field(
        ...,
        description="Email text to process and generate reply for",
        min_length=1,
        max_length=10000
    )


class WorkflowResponse(BaseModel):
    """Response model for workflow execution"""
    success: bool = Field(description="Whether the workflow completed successfully")
    output_text: Optional[str] = Field(None, description="Generated email reply text")
    error: Optional[str] = Field(None, description="Error message if workflow failed")


@app.get("/", tags=["Health"])
async def root():
    """Root endpoint"""
    return {
        "service": "Email Reply Workflow API",
        "status": "running",
        "version": "1.0.0"
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint for Azure Container Apps"""
    # Check if OPENAI_API_KEY is set
    api_key_configured = bool(os.getenv("OPENAI_API_KEY"))

    if not api_key_configured:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="OPENAI_API_KEY is not configured"
        )

    return {
        "status": "healthy",
        "api_key_configured": api_key_configured
    }


@app.post("/workflow", response_model=WorkflowResponse, tags=["Workflow"])
async def execute_workflow(request: WorkflowRequest):
    """
    Execute the email reply workflow

    This endpoint processes the input email text and generates an appropriate reply
    using the OpenAI Agents SDK.

    Args:
        request: WorkflowRequest containing the input email text

    Returns:
        WorkflowResponse with the generated reply or error information
    """
    logger.info(f"Received workflow request with input length: {len(request.input_text)}")

    try:
        # Create workflow input
        workflow_input = WorkflowInput(input_as_text=request.input_text)

        # Execute workflow
        result = await run_workflow(workflow_input)

        if result is None:
            logger.warning("Workflow returned None (approval rejected)")
            return WorkflowResponse(
                success=False,
                error="Workflow approval was rejected"
            )

        logger.info("Workflow completed successfully")
        return WorkflowResponse(
            success=True,
            output_text=result.get("output_text")
        )

    except Exception as e:
        logger.error(f"Workflow execution failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Workflow execution failed: {str(e)}"
        )


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": "Internal server error occurred"
        }
    )


if __name__ == "__main__":
    import uvicorn

    # Run the application
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        log_level="info",
        access_log=True
    )
