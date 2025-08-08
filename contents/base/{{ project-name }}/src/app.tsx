import { createBrowserRouter, RouterProvider } from '@modern-js/runtime/router';
import { router } from './router';

function App() {
  return <RouterProvider router={router} />;
}

export default App;