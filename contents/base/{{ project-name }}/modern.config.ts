import { appTools, defineConfig } from '@modern-js/app-tools';
import { moduleFederationPlugin } from '@module-federation/modern-js';
import { tailwindcssPlugin } from '@modern-js/plugin-tailwindcss';
//import { routerPlugin } from '@modern-js/plugin-router-v7';

// https://modernjs.dev/en/configure/app/usage
export default defineConfig({
  dev: {
    port: {{port}},
    host: 'localhost', // Bind only to localhost interface
    setupMiddlewares: [
      (middlewares) => {
        // Add static resource logging middleware for development
      },
    ],
  },
  server: {
    port: {{port}},
  },
  runtime: {
    router: true,
  },
  output: {
    // Use relative paths for static deployment
    assetPrefix: process.env.NODE_ENV === 'production' ? '/' : 'http://localhost:{{ port }}/',
  },
  tools: {
    rspack: {
      output: {
        publicPath: 'auto',
      },
      cache: false
    },
  },
  source: {
    entries: {
      main: './src/App.tsx', // Use app.tsx as the main entry point for framework mode
    },
  },
  plugins: [
    appTools({
      bundler: 'rspack', // Set to 'webpack' to enable webpack
    }),
    tailwindcssPlugin(),
    //routerPlugin(), // React Router v7 plugin
    moduleFederationPlugin(),
  ],
});
