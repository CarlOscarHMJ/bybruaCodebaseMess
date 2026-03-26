I am investigating a couple of years data measured on the Stavanger City Bridge

Dear LLM Model here are some info on the way that i like my code.

In general I'm using Matlab 2025B on an arch linux setup using Hyprland through the Wayland kernel.

I like my functions to contain a function description, but other then that no comments (Unless stricly necessary!).

I try to use the naming scheme camelCase, e.g. timeLine, thisIsMyImportantVariable, soOn.

Please try and keep the code in generel as clean and consice as possible without loosing readability, which is first priority.

Try not to repeat yourself and split into multiple functions instead.

My project is about analyzing data collected on the Stavanger city bridge. I have submitted two abstracts to two conferences.

Project Mandates: ByBrua Analysis
## Standards
- All plotting functions must support 'tiledlayout' and use LaTeX for labels.
- Data processing should prioritize vectorized operations over 'for' loops where possible.
## Workflow
- Before implementing new plots, check `functions/bridgeDataResultsVieweFunctions/` for existing helper functions.
- Maintain the interactivity in `plotSpectralShift.m`; all scatter plots should link to `inspectDayResponse.m`.
## AI Behavior
- Do not suggest Python alternatives for data analysis; stay strictly within MATLAB.
- Write using camelCase
- Dont use line comments
- Use write functions with a header (what does the function do + etc). 
- Use arguments for functions and use option as much as possible with default settings.
- USE MEANINGFUL VARIABLE NAMES! The code should be readable by itself!
