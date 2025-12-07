# Basic Research, Applied Research and Growth

**Abstract.** A large literature exists studying the returns to government spending on research and development. A smaller and more recent literature looks at how these returns vary over sundry kinds of research and development (R&D) spending. We contribute to this growing literature by building a regional exposure design which leverages the universe of government spending contracts across the United States (US). We divide the contract data up over US states and five federal agencies; the Department of Defense (DOD), Department of Energy (DOE), National Institute of Health (NIH), National Aeronautics and Space Administration (NASA). We combine the distribution of spending implied by the contract data with the aggregate shocks provided in [Fieldhouse and Mertens (2025)](https://andrewjfieldhouse.com/wp-content/uploads/2025/12/The_Return_to_Government_R_D_December_2025.pdf) and develop a novel instrument for regional growth in R&D spending. We estimate the dynamic effects of such spending using the local projections instrumental-variables (LPIV) estimator.

**Question(s):** What are the effects of government-sponsored research funding on growth? How do these affects vary over the basic-applied research divide?

## Data Sources
1. [Quarterly State GDP](https://www.bea.gov/data/gdp/gdp-state) - Go to the interactive tables.
2. [Usa Spending Contract Data](https://www.usaspending.gov/)

## Code Remarks and Run Order
**Stata Dependencies.**
1. [ivreghdfe](https://github.com/sergiocorreia/ivreghdfe). See link for installation instructions.

**Remark I.** You should set your working directory to the code folder. All file paths are relative the code folder.
