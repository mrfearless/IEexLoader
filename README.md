# ![](/IEex.png) IEexLoader

Please visit [github.com/Bubb13/IEex](https://github.com/Bubb13/IEex) for the details about the [IEex](https://github.com/Bubb13/IEex) project, which was created by [Bubb](https://github.com/Bubb13).

# Summary

> IEex is an executable extender for classic Infinity Engine games created and/or published by Bioware and Black Isle Studio
> 

IEexLoader was designed to help the [IEex](https://github.com/Bubb13/IEex) project. IEexLoader loads an IE game executable and injects a dynamic link library and then loads a lua dynamic link library to add lua support. The injected `IEex.dll` will load and execute the `M__IEex.lua` file which is stored in the override folder.

Currently IEexLoader works with:

- BG: 2.5.0.2
- BG2: 2.5.0.2
- IWD: 1.4.2.0
- IWD2: 2.0.1.0
- PST: 1.0.0.1

This project consists of two RadASM assembly projects:
- **IEex** - Creates the executable loader: `IEex.exe`
- **IEexDll** - Creates the injection dynamic link library: `IEex.dll`


# Technical Information

For details on the IEex loader's operation or the pattern database vist the wiki [here](https://github.com/mrfearless/IEexLoader/wiki)

# Build Instructions

See the [Build-Instructions](https://github.com/mrfearless/IEexLoader/wiki/Build-Instructions) wiki entry for details of building the projects.

# Download

The latest downloadable release is available [here](https://github.com/mrfearless/IEexLoader/blob/master/Release/IEexLoader.zip?raw=true)

