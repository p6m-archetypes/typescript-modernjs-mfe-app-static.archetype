import Layout from './pages/layout';
import {{ project-name | pascal_case }}Page from './pages/page';
import { createBrowserRouter } from '@modern-js/runtime/router';

// Define route configuration for instructions application
export const router = createBrowserRouter([
  {
    path: '/',
    element: <Layout />,
    children: [
      {
        index: true,
        element: <{{ project-name | pascal_case }}Page />,
      }
    ],
  },
]);