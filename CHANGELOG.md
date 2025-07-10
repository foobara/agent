## [0.0.16] - 2025-07-09

- Tell the llm about previous goals
- Allow agents to be nameless
- Improve support for killing a running agent

## [0.0.15] - 2025-07-09

- Make use of Ai.default_llm_model

## [0.0.14] - 2025-07-08

- Better handle serialization/pre-commit loading for various entity-depth scenarios

## [0.0.13] - 2025-07-06

- Eliminate NotifyUser... result_type to save tokens/improve accuracy
- Choose DescribeCommand for commands with inputs that haven't been described
- Log failure output when trying to determine commands/inputs

## [0.0.12] - 2025-07-05

- Choose DescribeCommand for commands that have inputs and haven't been described
- Log determine command/input failures when verbose

## [0.0.11] - 2025-07-01

- Fix some bugs with result type/value mismatches
- Eliminate ability to select command and inputs separately

## [0.0.10] - 2025-06-30

- Allow more retries
- Eliminate ability to select command and inputs separately

## [0.0.9] - 2025-06-28

- Relocate some common Determine* behavior into a DetermineBase
- Move goal to Context and make use of LlmBackedCommand#messages
- Simulating a DescribeCommand selection on failure
- Compacting the command log

## [0.0.8] - 2025-06-27

- Improve what is logged and its formatting when verbose
- Improve/experiment with what is stored in the command log
- Experiment with Atoms instead of Aggregates
- Add max_llm_calls_per_minute option

## [0.0.7] - 2025-06-23

- Improvements to result type handling
- Eliminate DescribeType command

## [0.0.6] - 2025-06-19

- Do not run next command with pre-cast inputs
- Make result_data and message_to_user required (probably unwise for message_to_user?)
- Simulate ListCommands and DescribeCommand being at start
- Add a verbose flag for debugging help
- Give each AccomplishGoal its own command call count
- Convert entities to their aggregates as input and primary keys as output

## [0.0.5] - 2025-05-30

- Don't require agents to have a name

## [0.0.4] - 2025-05-30

- Refactor agent to be a command connector

## [0.0.3] - 2025-05-30

- Increase the retries, attempt to improve command descriptions,
  and attempt to improve the information stored in the context/command log
- Add some safeguards around changing the result type too late in the process
- Add an agent state machine and a kill! method

## [0.0.2] - 2025-05-27

- Add maximum_call_count option
- Try getting the command and inputs together to reduce calls
- Tweaks to algorithms and improvements to what is stored in context/command_log

## [0.0.1] - 2025-05-21

- Initial release

## [0.0.0] - 2025-05-19

- Project birth
