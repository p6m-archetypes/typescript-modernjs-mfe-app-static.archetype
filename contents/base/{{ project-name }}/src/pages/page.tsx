import {{ project-name | pascal_case }}Content from '../components/{{ project-name }}-content';
import './index.css';

export default function {{ project-name | pascal_case }}Page() {
  return <{{ project-name | pascal_case }}Content />;
};
