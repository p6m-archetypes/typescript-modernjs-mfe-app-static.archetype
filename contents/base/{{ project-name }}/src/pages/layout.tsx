import { Outlet } from '@modern-js/runtime/router';
import './index.css';

export default function Layout() {
  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 p-8">
      <Outlet />
    </div>
  );
}
