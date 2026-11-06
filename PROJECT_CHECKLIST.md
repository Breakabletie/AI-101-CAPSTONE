# Minimum Completion Criteria

Your capstone is complete when you have produced all of the following:

    One complete Spec Bundle
    One complete Test Package
    One implemented feature
    One reviewed feature / PR package
    Verification evidence
    A final presentation, written up

# How to Work Through This Capstone

The capstone runs in seven sections, with an eighth for anyone whose first cycle finishes clean:

    1. Project selection. Choose your project, select a technical track, and identify one capability.
    2. Spec Bundle. Complete goals, non-goals, constraints, EARS requirements, stories, acceptance criteria, and an ADR.
    3. Slice planning. Create 4–8 slices and choose one feature to fully implement.
    4. Build. Implement one feature and document AI usage, decisions, and verification.
    5. Testing, verification, and debugging. Complete the Test Package and capture evidence.
    6. Review package. Prepare a review package another person could understand without a walkthrough.
    7. Presentation. Write up a presentation that demonstrates the feature and the delivery cycle.
    8. The second cycle. If the first feature is genuinely complete, take the next slice through Sections 4 to 6 and add it to the demonstration.

# Definition of Done — Section 1

    Project selected.
    One software capability identified.
    Success criteria defined.
    Out-of-scope items defined.
    Technical track selected.
    I can explain the capstone feature in one sentence.

## Your Notes
    Record each of these in your working document:

    What workflow does your software solution support? This can be carried over from AI 220 if you came up with one then
    Original AI 220 goal, if used
    Project name
        Post Launch Requirements(PLR) Program
    Problem statement
        This program is setting out to automate an Operators task of verifying if any new PLRs have been met from the previous days tasks.
    Software capability being built
        A program that will quickly and accurately check task logs against PLRs
    Primary users affected
        Operators
    Why this problem matters
        Doing this task manually is very time intensive and given the fast pase nature of the operators work environment the same checks can accidently be multiple times or get skipped entirely. This task has contibuted to mission shortcomings in other areas due to this task requirement. Enabling the operators the ability to operate a tool to make the checks automatically would increase mission capability, completion, and accuracy.
    Success criteria for the capstone feature
        Be able to access and read operators mission software task logs.
        Be able to access and read mission PLR tracking document
        Be able to identify newly achieved PLRs
        Be able to alert the operator of identified achieved PLRs
        Be able to update the PLR with step by step updates and add unique SATS and start tracking their requirements
        Prompt the operator to complete subsiquent mission PLRs
        Prompt the operator to confirm the subsiquent mission PLRs have been completed
        Be able to update the PLR document with newly achieved PLRs and operator accountability
    Explicitly out of scope
        The program should not edit the mission software task logs
        The program should not edit the specific PLR in the PLR document with out conformation from the operator that subsiquent mission PLRs are completed

    Technical track: deterministic or LLM-integrated
        Deterministic
    If LLM-integrated: API access status, fallback plan, and verification strategy


# Definition of Done — Section 2

    Goals documented and measurable.
    Non-goals documented.
    Constraints documented.
    Assumptions and impacts documented.
    Success metrics defined.
    At least five EARS requirements completed.
    At least three user stories completed.
    Acceptance criteria written in Given/When/Then format.
    One ADR completed.
    The feature is ready to slice and build.

# Your Notes — Spec Bundle

    Record each of these in your working document:

    Feature name - PLR achievment detection and completion
    Goal 1 — specific and measurable
        The program will be able to accuratly and consistantly identify a PLR achievement
    Goal 2 — specific and measurable
        The program will be able to update the PLR document with new PLR achievments with operator accountability
    Non-goal 1 — what the feature must not do
        The program will generate a GUI
    Non-goal 2 — what the feature must not do
        The program will not hold responsibilty for the completion of subsaquent PLRs
    Non-goal 3 — what the feature must not do
        The program will not be an automatic tool but one the operator is responsible for tasking/starting
    Constraint 1 — technical, data, policy, cost, or access constraint
        The logs and PLR document data will be in excel documents
    Constraint 2 — technical, data, policy, cost, or access constraint

    Assumption 1 and impact if wrong
        Program will have access and ability to read/write to input documents
        If wrong the programs functionality will become non-existant
    Assumption 2 and impact if wrong

    Success metric 1
        Program is able to identify when a PLR is newly achieved
    Success metric 2
        Program is able to hold operators accountable for subaquent PLR completion

    EARS Requirements

        In your working document, number your EARS requirements. At least five, covering more than one pattern. For each one record:

            Pattern — which of the five EARS sentence patterns it uses
            Requirement — the requirement itself
            Example or counter-example — what satisfies it, or what would violate it

            1. The program shall compare the mission software task logs against the PLR document

            2. When a PLR is found to be achieved, the program shall update the PLR document stating that the achievement has been made with task informetion, record the operator who is using the tool, and that the subsaquent PLRs have not been completed

            3. If a SAT is in the task logs but not in the PLR document, the program will update the PLR document with SAT information and PLRs

            4. When a PLR is found to be achieved, the program shall notify the operator and wait for the operators conformation that the subsiquent PLRs have been completed

            5. While the operator has not indicated that the subsaquent PLRs have been completed, the program shall wait until the operator has indicated that the subsaquent PLRs have been completed

            6. When the operator has not indicated that the subsaquent PLRs have been completed, the program will update the PLR document indicating that the subsaquent PLRs have been completed

    User Stories and Acceptance Criteria

        In your working document, number your user stories. At least three. For each one record:

            The story, in As a / I want / So that form
            Its acceptance criteria, in Given / When / Then form

            1. As an operator, I want the program to accuratly determine when a new PLR is achieved, so that other mission tasks and requirements can be achieved

            2. As an operator, I want the program to require my conformation that my subsaquent PLRs are complete, so that I dont forget to complete them.

            3. As a mission supravisor, I want the program to track what operator was notified of achieved PLRs, so that if subsiquent PLRs are not completed we have a mechanism for accountability

    ADR

        Record each of these in your working document:

            ADR title
                Operator accountability
            Context — what decision needed to be made?
                The PLR document not updated on a set schedule so the information can become stale. We need a way to update the document with new PLR achievements so that we dont need to wait for mission managment to manually update it. This waiting will cause some confusing as different crews/sites will ask the question "has this been done already or am I the first to see it?" Allowing the operators to make ad hoc edits to the document could introduce the issue of a requirement being 'satisfied' but never actually being satisfied and know one would know who made that change
            Decision — what did you choose?
                An accountability implementation, that would be tracked in the PLR document so that any updates/changes in the document would be tracked for individual SATs
            Options considered
                accountability implementation
                widen the document access to NCOICs or Mission Supravisors
            Rationale — why this option?
                widening the access to Mission Supravisors is a bad idea because of the constant changes in crews and schedules many operators often have to fill the role of Mission Supravisor
                Giving access the NCOICs give a simular issue due to crew/schdeule changes
                The accountability implementation would give the access to edit the document down to the individual who discovered the PLR achievement while also holding the individual accountabile for the completion of the subsaquent requirements
                Previously an operator manually checking for achieved PLRs could find one and decide they didnt want to do the work and ignore it and there was no one that would verify this without peer review
            Consequences — what tradeoffs are accepted?
                Giving all operators the access to update this document via the PLR program the risk for achieved PLR follow on requirements not being completed is there but with the accountibility mechanism we have who and when
            Revisit triggers — what would make you reconsider?
                If operators a consistantly not completing requirements and crew leadership cannot enforce accountibility leadership could revisit the mechanism or create new task requirements for the PLR documents information accuracy




# Definition of Done — Section 3

    4–8 slices identified, or a smaller justified slice set documented.
    Every planned slice maps to acceptance criteria.
    Every planned slice has test targets.
    Dependencies are identified.
    One feature or slice selected for full completion.
    Selected feature is small enough to implement, test, review, and demo.

# Your Notes — Slice Plan

    In your working document, number your slices. Four to six is the usual range — fewer and they are too big to review, more and you will not finish. For each slice record:


        Scope — one sentence
        Acceptance criteria addressed
        Test targets — what you would test
        Dependencies — which slices must come first

        1. Implement PLR comparisons and accountability mechanisms
        2. Implement option to select specific date of task log that is to be processed
        3. Implement tests and checks with logs for each of the tests
        4. Implement User frendly GUI to visualy see program process
        5. Implement API to pull recent launch information to update the PLR document



    Record each of these in your working document:

        Which slice or feature will be fully completed in this capstone?
            Slice 1 will be fully completed in this capstone
            stretch goal will be to work on slice 2 and 3
        Why is this the right first completed feature?
            Slice 1 is the basic functionality of the program and all other features will be build around this or to complement it
        Which slices are intentionally deferred?
            slice 3 is defered due to not having the base functionality of the program complete, what point is there in a GUI without function
            slice 4 is defered due to the launch calander I pull from is not available to me currently
        What must be true before the selected feature can be reviewed?
            We have task logs

# Definition of Done — Section 4

    One feature implemented.
    AI usage documented.
    Human review of generated work documented.
    Implementation decisions documented.
    Feature can be demonstrated.
    Known limitations documented.

# Your Notes — Build Evidence

    Record each of these in your working document:

        Feature implemented
        What AI generated
        What you modified manually
        What you rejected or rewrote
        Key implementation decisions
        Files, components, screens, or functions changed
        How you verified the feature during the build
        Known limitations of the implementation

        Feature implemented
            Dummy Satallite task generator
        What AI generated
            Script that generates exel task logs
            satallite state json that resets what date the logs generate from adn the list of satallites/info that will populate tasks
            Decision record
        What you modified manually
        What you rejected or rewrote
            It generated incorect SPUTs, stop/start times, so i prompted the tool to make the adjustments
        Key implementation decisions
        Files, components, screens, or functions changed
        How you verified the feature during the build
        Known limitations of the implementation

        Feature implemented
            Implement PLR comparisons and accountability mechanisms
        What AI generated
        What you modified manually
        What you rejected or rewrote
        Key implementation decisions
        Files, components, screens, or functions changed
        How you verified the feature during the build
        Known limitations of the implementation

# Definition of Done — Section 5

    Happy path test or check completed.
    Boundary test or check completed.
    Edge case test or check completed.
    Negative test or check completed.
    Tests or checks trace back to acceptance criteria.
    Verification evidence captured.
    Known test gaps documented.
    Debugging log completed if bugs were found.

# Your Notes — Test Package

In your working document, number your tests. Cover the happy path, a boundary, an edge case and a negative case at minimum. For each test record:

    Test type — happy path, boundary, edge, or negative
    Acceptance criterion it maps to
    Input or setup
    Expected result
    Where the evidence lives — output, log, screenshot


# Your Notes
    Spec Gaps and Verification Notes

        Record each of these in your working document:

            What spec gap did testing reveal, if any?
            What test or check proves the main feature works?
            What behavior remains untested?
            What evidence will you show in your presentation?
            What would you test next with more time?

    Debugging Log

        Add one row for each bug or unexpected behavior you find.

        In your working document, keep a running log. One entry per bug or unexpected behavior, however small. For each record:

            The bug or unexpected behavior
            Hypothesis — what you thought was causing it
            Test performed
            Result
            Fix — and how many lines it changed

# Definition of Done — Section 6

    Review package completed.
    What changed is clear.
    Why the change exists is tied to acceptance criteria.
    AI-assisted work is disclosed.
    Verification notes included.
    Risk callouts included.
    Next slice identified.
    Another person could understand the feature without a verbal walkthrough.

# Your Notes — Review Package

    Record each of these in your working document:

        What changed — one-paragraph summary
            The origional project only had base functionality this new pass at the project has added 2 features, the ability to choose between task logs and a test suite.
        Why this change matters
            The ability to choose what test log you want to run the programon is important to be able to do so that operators can run previous days tasks. The task log is only fully completed and quality controlled the next day.
            The test suite is a health and wellness tool to track the programs accuracy and diagnose any issues the program might encounter.
        Acceptance criteria addressed
            The test suite was a nessessary addition as acceptance criteria of the output was human verified after each run. The suite now has a built in test kit so that it can run its out acceptance criteria and if things change the acceptance criteria can be edited through the tests.
        AI-assisted work included
            The AI assisted work included work on both features with human validation and acceptance.
        Human-authored or human-modified work included
            Human work included fabricating tests to address key areas and validation and acceptance of AI assisted work on both features.
        Verification notes
            The AI assisted work needed some slight tweaks and reworks to get what I expressly wanted.
        Test evidence
            Test evidance can be reviewed under ..\logs\tests\
        Risk callouts and known limitations
            The program cannot verify if the operator actually completed subsaquent requirements.
        Files, screens, or components that most need review attention

        Next slice if work continued
            GUI, creating a user friendly and easy to use and navigate system to cleanly see files, options, logs, run progress,
        Rollback or fallback considerations, if relevant
            If operators are failing to complete subsaquent requirements mission leadership will need to review the situation.

# Definition of Done — Section 7

    Presentation follows the required structure.
    Testing evidence is included.
    Review package is referenced.
    Lessons learned identified.

# Your Notes — Presentation

    Record each of these in your working document:

        Problem in one sentence
        Most important spec decision
        Feature being demonstrated
        Evidence that the feature works
        How AI was used responsibly
        Risk or limitation to acknowledge
        Next slice if work continued

# Section 8 — The Second Cycle

    If your first feature is genuinely complete, take another slice through the same cycle.

# Final Check

    My complete Spec Bundle is finished.
    My complete Test Package is finished.
    One feature is implemented.
    One feature is reviewed through the review package.
    Verification evidence is collected and ready to show.
    My written presentation is complete.
    My project scope remained controlled.
    I can point to the test that proves the feature does what the spec says.
    I can explain what was completed, what was not completed, and what would come next.

