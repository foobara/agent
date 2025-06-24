## [0.0.7] - 2025-06-23

- 

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
