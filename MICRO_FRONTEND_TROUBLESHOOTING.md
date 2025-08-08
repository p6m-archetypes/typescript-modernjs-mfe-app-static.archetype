# Micro-Frontend Troubleshooting Guide

## Overview
This document summarizes the key issues encountered and solutions implemented while debugging a Modern.js micro-frontend setup with module federation.

## Issues Encountered & Solutions

### 1. ChunkLoadError: Loading chunk 708 failed

**Problem:**
```
ChunkLoadError: Loading chunk 708 failed.
(missing: http://localhost:3000/static/js/async/708.8173cefc.js)
```

**Root Cause:**
The issue was caused by wrapping `loadRemote()` with `React.lazy()`, which created an unnecessary webpack chunk layer. This caused webpack to generate phantom chunks that didn't actually exist in either the shell or remote applications.

**Solution:**
Replace the `React.lazy` wrapper with direct `loadRemote` usage:

```tsx
// ❌ PROBLEMATIC - Creates phantom chunks
const Component = useMemo<React.ComponentType>(
  () => React.lazy(() => loadRemote(componentPath) as Promise<{ default: React.ComponentType }>),
  [componentPath],
);

// ✅ CORRECT - Direct loadRemote usage
const [Component, setComponent] = useState<React.ComponentType | null>(null);
const [loading, setLoading] = useState(true);

useEffect(() => {
  setLoading(true);
  loadRemote(componentPath)
    .then((module: any) => {
      setComponent(() => module.default);
      setLoading(false);
    })
    .catch((error) => {
      console.error('Failed to load remote component:', error);
      setLoading(false);
    });
}, [componentPath]);
```

**Configuration Fix:**
Added `publicPath: 'auto'` in rspack configuration to ensure proper chunk URL resolution:

```ts
// modern.config.ts (remote app)
tools: {
  rspack: {
    output: {
      publicPath: 'auto',
    },
  },
},
```

### 2. React Version Mismatch

**Problem:**
```
TypeError: undefined is not an object (evaluating 'ReactSharedInternals.ReactCurrentDispatcher')
```

**Root Cause:**
Version conflict between shell app (React 18.3.1) and remote app (React 19.0.0). Module federation requires consistent React versions across all micro-frontends when using singleton sharing.

**Solution:**
Align React versions across all applications:

```json
// Both shell and remote package.json
{
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.23",
    "@types/react-dom": "^18.3.7"
  }
}
```

**Module Federation Configuration:**
Ensure singleton sharing is properly configured:

```ts
// module-federation.config.ts
shared: {
  react: { singleton: true },
  'react-dom': { singleton: true },
}
```

### 3. Build Cache Issues

**Problem:**
Build systems sometimes cache outdated configurations, causing persistent errors even after fixes.

**Solution:**
Clear specific cache directories when encountering persistent build issues:

```bash
# Clear Modern.js cache
rm -rf demo-shell/node_modules/.modern-js
rm -rf demo-customer-app/node_modules/.modern-js

# Force dependency reinstall when needed
rm -rf node_modules pnpm-lock.yaml
pnpm install
```

### 4. Remote Entry Loading Issues

**Problem:**
```
Error: [ Federation Runtime ]: remoteEntryExports is undefined
```

**Root Cause:**
This typically occurs when:
- Remote application isn't running
- Remote entry URL is incorrect
- Module federation configuration mismatch

**Solution:**
1. Verify remote app is running on expected port
2. Check remote entry URL accessibility:
   ```bash
   curl -I http://localhost:3001/static/remoteEntry.js
   ```
3. Ensure proper module federation configuration alignment

## Key Configuration Files

### Shell App (demo-shell)

**modern.config.ts:**
```ts
export default defineConfig({
  dev: { port: 3000 },
  server: { port: 3000 },
  output: {
    assetPrefix: process.env.NODE_ENV === 'production' ? '/' : 'http://localhost:3000/',
  },
  plugins: [
    appTools({ bundler: 'rspack' }),
    moduleFederationPlugin(),
    routerPlugin(),
  ],
});
```

**module-federation.config.ts:**
```ts
export default createModuleFederationConfig({
  name: 'shell',
  remotes: {
    demo_customer_app: 'demo_customer_app@http://localhost:3001/static/remoteEntry.js',
  },
  shared: {
    react: { singleton: true },
    'react-dom': { singleton: true },
  },
});
```

### Remote App (demo-customer-app)

**modern.config.ts:**
```ts
export default defineConfig({
  dev: { port: 3001 },
  server: { port: 3001 },
  output: {
    assetPrefix: process.env.NODE_ENV === 'production' ? '/' : 'http://localhost:3001/',
  },
  tools: {
    rspack: {
      output: {
        publicPath: 'auto',
      },
    },
  },
  plugins: [
    appTools({ bundler: 'rspack' }),
    moduleFederationPlugin(),
    tailwindcssPlugin(),
    routerPlugin(),
  ],
});
```

**module-federation.config.ts:**
```ts
export default createModuleFederationConfig({
  name: 'demo_customer_app',
  manifest: { filePath: 'static' },
  filename: 'static/remoteEntry.js',
  exposes: {
    './demo-customer-app-content': './src/components/demo-customer-app-content.tsx',
  },
  shared: {
    react: { singleton: true },
    'react-dom': { singleton: true },
  },
});
```

## Best Practices

### 1. Dynamic Component Loading
- Use direct `loadRemote()` without `React.lazy()` wrapper
- Implement proper loading states with `useState`/`useEffect`
- Add error handling for failed module loads

### 2. Version Management
- Keep React versions aligned across all micro-frontends
- Use singleton sharing for React and React DOM
- Regularly audit dependency versions

### 3. Development Setup
- Ensure unique ports for each micro-frontend
- Use `publicPath: 'auto'` for dynamic chunk resolution
- Clear build caches when encountering persistent issues

### 4. Debugging Steps
1. Check if all applications are running on expected ports
2. Verify remote entry accessibility
3. Check browser console for specific error messages
4. Validate React version compatibility
5. Clear build caches if issues persist

## Common Error Patterns

| Error | Likely Cause | Solution |
|-------|--------------|----------|
| `ChunkLoadError: Loading chunk XXX failed` | `React.lazy` wrapper around `loadRemote` | Use direct `loadRemote` with `useState`/`useEffect` |
| `ReactSharedInternals.ReactCurrentDispatcher` | React version mismatch | Align React versions across apps |
| `remoteEntryExports is undefined` | Remote app not running or config mismatch | Check remote app status and configuration |
| Build compilation errors | Stale cache | Clear `.modern-js` cache directories |

## Additional Resources

- [Module Federation Documentation](https://module-federation.io/)
- [Modern.js Module Federation Guide](https://modernjs.dev/guides/topic-detail/micro-frontend/module-federation.html)
- [React Version Compatibility](https://react.dev/versions)
