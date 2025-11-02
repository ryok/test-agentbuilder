from agents import Agent, ModelSettings, TResponseInputItem, Runner, RunConfig, trace
from openai.types.shared.reasoning import Reasoning
from pydantic import BaseModel

my_agent = Agent(
  name="My agent",
  instructions="入力をメールの文章と理解して，返信文章を作成して",
  model="gpt-5",
  model_settings=ModelSettings(
    store=True,
    reasoning=Reasoning(
      effort="low",
      summary="auto"
    )
  )
)


def approval_request(message: str):
  # TODO: Implement
  return True

class WorkflowInput(BaseModel):
  input_as_text: str


# Main code entrypoint
async def run_workflow(workflow_input: WorkflowInput):
  with trace("test workflow"):
    state = {

    }
    workflow = workflow_input.model_dump()
    conversation_history: list[TResponseInputItem] = [
      {
        "role": "user",
        "content": [
          {
            "type": "input_text",
            "text": workflow["input_as_text"]
          }
        ]
      }
    ]
    approval_message = ""

    if approval_request(approval_message):
        my_agent_result_temp = await Runner.run(
          my_agent,
          input=[
            *conversation_history
          ],
          run_config=RunConfig(trace_metadata={
            "__trace_source__": "agent-builder",
            "workflow_id": "wf_6902c65510d48190b00cc15ada9afdb201102001bbe3ff0a"
          })
        )

        conversation_history.extend([item.to_input_item() for item in my_agent_result_temp.new_items])

        my_agent_result = {
          "output_text": my_agent_result_temp.final_output_as(str)
        }
        return my_agent_result
    else:
        return None

