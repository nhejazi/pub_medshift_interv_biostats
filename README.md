Code to reproduce the results reported in ["Nonparametric causal mediation
analysis for stochastic interventional (in)direct
effects"](https://arxiv.org/abs/2009.06203) by [N.S.
Hejazi](https://nimahejazi.org/), [K.E.
Rudolph](https://kararudolph.github.io/), [M.J. van der
Laan](https://vanderlaan-lab.org/), and [I. Diaz](https://www.idiaz.xyz/) in
_Biostatistics_ (2022)

* To reproduce the simulation study reported in the manuscript, examine the
  `simulation` subdirectory and the comments in the included `README.md`.
* To assess the data analysis results reported in the manuscript, examine the
  `application` subdirectory and the code it contains. The data from the X:BOT
  trial has not (yet) been released due to data sharing agreements; however,
  the exact `R` code applied to the dataset is included in this subdirectory.

Note that both directories reference the `intmedlite` auxiliary `R` package,
which provides the estimation machinery used for the both the simulation studies
and real-world data analysis. To support accessibility of the methodology, the
functionality from this auxiliary package is presently in the process of being
incorporated into our [`medshift` package](https://github.com/nhejazi/medshift);
this note will be updated to point to that functionality once initial
integration and testing have been completed.

Should any concerns arise, please [file an
issue](https://github.com/nhejazi/pub_medshift_interv_biostats/issues/new) with
a clear description of the problem encountered.
