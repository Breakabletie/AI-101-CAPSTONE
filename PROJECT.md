# Post Launch Requirements Project

**Fill this in once, when you start. Revise it when the project changes, not per task.**

Read alongside `AGENTS.md` by anything working in this repository.

---

## What this project is

This project will read satallite task logs and compare daily completed tasks against the mission's post launch requirements document, which tracks what steps have completed/no completed following a satallite launch. The task the repo completes is what current operators have to do by hand, mission operators are required to manually verify if a specific mission requirement has been achieved for satallites. This process is time consuming, tedious, prone to human error, and can lead to missed or failed mission tasking in other areas. This project aims to automate those checks with speed and accuracy so that operators can compete subsaquent tasks quicker.

## Who the output is for

Users
     Mission operators will utilize this tool
Actors
     Mission operators will act on achieved PLRs
     Mission leaders ship will be able to enact accountability actions if mission operators fail to complete subsaquent PLRs
     Analysis cell will be able to complete subsaquent PLRs following mission operators complete their PLRs
Readers
     Mission operators will read the PLR document durin and after runtime to verify project output is correct
     Mission leaders will monitor PLR document to track completion of mission operator subsaquent PLRs

## What good looks like here
>
Good looks like:
     The program user/operator is notified when newly achieved requirements are detected.
     The program user/operator is prompted to verify that subsaquent requirements are completed.
     The program acuratly and consistently detects newly achieved requirements.
     The program can/has access to the satallite task logs and mission PLR document.
     The velidity of newly achieved requirements is ALWAYS VERIFIED prior to updating the PLR document.
     The operator is accountable for subsaquent requirement completion by keeping track of which operator complete/fails to complete requirements.

## What this project does not do

This project does not take responsibility for the operator failing to complete this step in the requirements workflow.
This project does not take responsibility for the opreator failing to complete the subsaquent requirements in the workflow.

## Standing decisions

<!-- Choices already made that shouldn't be relitigated each time: which tools, which
     conventions, which formats. Link to docs/decisions/ for the reasoning. -->

## What stays with a human

The operator is still responsible for checking the PLR document to verify the validity of a newly achieved requirement.
The operator is still responsible for running this tool so that the step this automates is completed
The opreator is still responsible for the subsaquent requirements that follow a newly achieved requirement.
