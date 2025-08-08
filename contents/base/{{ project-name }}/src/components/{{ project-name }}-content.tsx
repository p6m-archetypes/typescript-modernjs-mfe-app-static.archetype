export default function {{ project-name | pascal_case }}Content() {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="text-center mb-12">
        <h1 className="text-5xl font-bold text-gray-900 dark:text-white mb-6">
          {{ project-title }}
        </h1>
        <p className="text-xl text-gray-600 dark:text-gray-400 mb-8">
          Some interesting things you might want to try...
        </p>
        <div className="w-24 h-1 bg-blue-500 mx-auto rounded-full"></div>
      </div>
    </div>
  );
}
