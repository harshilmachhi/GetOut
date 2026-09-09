import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const headerUrl = new URL(
  '../node_modules/expo-modules-jsi/apple/Sources/ExpoModulesJSI-Cxx/include/RuntimeScheduler.h',
  import.meta.url,
);
const headerPath = fileURLToPath(headerUrl);
const header = await readFile(headerPath, 'utf8');
const fixedHeader = header
  .replace('SWIFT_RETURNS_RETAINED RuntimeScheduler(void *scheduler, ScheduleFn fn)', 'RuntimeScheduler(void *scheduler, ScheduleFn fn)')
  .replace('SWIFT_RETURNS_RETAINED RuntimeScheduler() {}', 'RuntimeScheduler() {}');

if (fixedHeader !== header) {
  await writeFile(headerPath, fixedHeader);
  console.log('Applied Xcode 26 compatibility fix for expo-modules-jsi.');
}

const manifestUrl = new URL('../node_modules/expo-modules-jsi/apple/Package.swift', import.meta.url);
const manifestPath = fileURLToPath(manifestUrl);
const manifest = await readFile(manifestPath, 'utf8');
if (manifest.includes('swiftLanguageModes: [.v5],')) {
  await writeFile(manifestPath, manifest.replace('swiftLanguageModes: [.v5],', 'swiftLanguageModes: [.v6],'));
}

const runtimeUrl = new URL(
  '../node_modules/expo-modules-jsi/apple/Sources/ExpoModulesJSI/Runtime/JavaScriptRuntime.swift',
  import.meta.url,
);
const runtimePath = fileURLToPath(runtimeUrl);
const runtime = await readFile(runtimePath, 'utf8');
const fixedRuntime = runtime.includes('private struct UnsafeTransfer<Value>: @unchecked Sendable')
  ? runtime
  : runtime
  .replace('nonisolated(unsafe) let resultPtr = resultPtr', 'let resultPtr = UnsafeTransfer(resultPtr)')
  .replace('try context.get(propertyName).writeJSIValue(to: resultPtr)', 'try context.get(propertyName).writeJSIValue(to: resultPtr.value)')
  .replace('private func createFunctionClosure(', 'private struct UnsafeTransfer<Value>: @unchecked Sendable {\n  let value: Value\n\n  init(_ value: Value) {\n    self.value = value\n  }\n}\n\nprivate func createFunctionClosure(')
  .replaceAll('nonisolated(unsafe) let thisPtr = thisPtr', 'let thisPtr = UnsafeTransfer(thisPtr)')
  .replaceAll('nonisolated(unsafe) let argumentsPtr = argumentsPtr', 'let argumentsPtr = UnsafeTransfer(argumentsPtr)')
  .replaceAll('nonisolated(unsafe) let resultPtr = resultPtr', 'let resultPtr = UnsafeTransfer(resultPtr)')
  .replaceAll('UnsafeMutablePointer(mutating: thisPtr).move()', 'UnsafeMutablePointer(mutating: thisPtr.value).move()')
  .replaceAll('JavaScriptValuesBuffer(runtime, start: argumentsPtr, count: argumentsCount)', 'JavaScriptValuesBuffer(runtime, start: argumentsPtr.value, count: argumentsCount)')
  .replaceAll('JavaScriptUnownedValue(runtime.pointee, thisPtr)', 'JavaScriptUnownedValue(runtime.pointee, thisPtr.value)')
  .replaceAll('writeJSIValue(to: resultPtr)', 'writeJSIValue(to: resultPtr.value)');

if (fixedRuntime !== runtime) {
  await writeFile(runtimePath, fixedRuntime);
  console.log('Applied Swift 6 pointer-transfer fix for expo-modules-jsi.');
}
