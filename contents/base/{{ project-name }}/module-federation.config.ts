import { createModuleFederationConfig } from '@module-federation/modern-js';

export default createModuleFederationConfig({
  name: '{{ project-name | snake_case }}',
  manifest: {
    filePath: 'static',
  },
  filename: 'remoteEntry.js',
  exposes: {
    './{{ project-name }}-content': './src/components/{{ project-name }}-content.tsx',
  },
  shared: {
    react: { singleton: true },
    'react-dom': { singleton: true },
  },
});
