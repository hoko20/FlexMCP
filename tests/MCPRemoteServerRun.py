#!/usr/bin/env python3
import pathlib,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
sdk=pathlib.Path('/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')
if not sdk.exists():sdk=pathlib.Path(subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip())
with tempfile.TemporaryDirectory(prefix='dylix-mcp-server-') as folder:
 output=pathlib.Path(folder)/'test'
 subprocess.run(['xcrun','clang','-isysroot',str(sdk),'-fobjc-arc','-Wno-incompatible-pointer-types','-framework','Foundation','-framework','Network','-framework','Security',str(root/'tests/MCPRemoteServerTests.m'),str(root/'App/Remote/DXRemoteMCP.m'),str(root/'App/Remote/DXFlexBridge.m'),str(root/'App/Remote/DXRemoteAccess.m'),'-o',str(output)],check=True)
 subprocess.run([str(output)],check=True,timeout=60)
