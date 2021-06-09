# VocalTractMatLab
A MATLAB wrapper for the VocalTractLab API

[![View VocalTractMatLab on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://de.mathworks.com/matlabcentral/fileexchange/93750-vocaltractmatlab)

## Getting started
1. Check out the repository *recursively*:
```
git clone --recurse-submodules https://github.com/TUD-STKS/VocalTractMatLab
```

2. Change the working directory of MATLAB to the folder you cloned the repository into.

3. Run the script ``vtlApiTest.m``. The first time you run this script, the C++ library underlying the MATLAB wrapper will be built for your system using CMake (or, on Windows, MSBuild as a fallback).

4. Look at the script ``vtlApiTest.m`` for a usage example and the class ``VTL.m`` for (a little bit of) help regarding the individual functions.

## Troubleshooting
If you get an error regarding "CMake not found", you should install [CMake](https://cmake.org/download/) for your platform.


Happy synthesizing!
