#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_DIR="$HOME/development/demos/mfe-demo-$(date +%Y%m%d%H%M%S)"
SHELL_NAME="demo-shell"
APP_NAME="demo-customer-app"
SHELL_PORT=3000
APP_PORT=3001

log() {
    echo -e "$1"
}

log "${BLUE}==============================================
Modern.js MFE Demo Setup
==============================================${NC}"

# Clean up existing demo
if [ -d "$DEMO_DIR" ]; then
    log "${YELLOW}Cleaning up existing demo directory...${NC}"
    rm -rf "$DEMO_DIR"
fi

mkdir -p "$DEMO_DIR"
cd "$DEMO_DIR"

log "${GREEN}Creating demo projects in $(pwd)${NC}"

# Generate shell project
log "${BLUE}Generating shell application...${NC}"
cat > shell_answers.yaml << EOF
organization-name: "demo.example"
project-title: "Demo Shell"
project-prefix: "demo"
team-name: "platform"
port: "3000"
org-name: "demo.example"
solution-name: "$SHELL_NAME"
organization_name: "demo.example"
org_name: "demo.example"
solution_name: "$SHELL_NAME"
EOF

archetect render -U /Users/joshuarothe/development/ybor/p6m-archetypes/typescript-modernjs-mfe-shell.archetype --answer-file shell_answers.yaml

# Generate app project
log "${BLUE}Generating MFE application...${NC}"
cat > app_answers.yaml << EOF
organization-name: "demo.example"
project-title: "Customer Management"
project-prefix: "demo-customer"
port: "3001"
team-name: "platform"
org-name: "demo.example"
solution-name: "$APP_NAME"
organization_name: "demo.example"
org_name: "demo.example"
solution_name: "$APP_NAME"
EOF

archetect render -U /Users/joshuarothe/development/ybor/p6m-archetypes/typescript-modernjs-mfe-app-static.archetype --answer-file app_answers.yaml

# Update shell to consume the MFE app
log "${BLUE}Configuring shell to consume MFE app...${NC}"
cd "$SHELL_NAME"

# Update app.tsx for Module Federation
cat > src/App.tsx << 'EOF'
import { RouterProvider } from '@modern-js/runtime/router';
import { router } from './routing/router';

function App() {
  return <RouterProvider router={router} />;
}

export default App;
EOF

# Update shell's modern.config.ts to add the remote
cat > modern.config.ts << 'EOF'
import { appTools, defineConfig } from '@modern-js/app-tools';
import { moduleFederationPlugin } from '@module-federation/modern-js';
import { routerPlugin } from '@modern-js/plugin-router-v7';

export default defineConfig({
  dev: {
    port: 3000,
    host: 'localhost',
  },
  runtime: {
    router: true,
  },
  server: {
    port: 3000,
  },
  output: {
    assetPrefix: process.env.NODE_ENV === 'production' ? '/' : 'http://localhost:3000/',
  },
  source: {
    entries: {
      main: './src/App.tsx',
    },
  },
  plugins: [
    appTools({
      bundler: 'rspack',
    }),
    moduleFederationPlugin(),
    routerPlugin(),
  ],
});
EOF

# Create module federation config for shell
cat > module-federation.config.ts << 'EOF'
import { createModuleFederationConfig } from '@module-federation/modern-js';

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
EOF

# Create router configuration
cat > src/routing/router.tsx << 'EOF'
import HomePage from '@/pages/home';
import MainLayout from '@/pages/main-layout';
import ContentHandler from '@/pages/content-handler';
import { createBrowserRouter } from '@modern-js/runtime/router';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <MainLayout />,
    children: [
      {
        index: true,
        element: <HomePage />,
      },
      {
        path: '/customers',
        element: <ContentHandler name="Customer Management" title="Customer Management App" componentPath="demo_customer_app/demo-customer-app-content" />,
      }
    ],
  },
]);
EOF

# Create main layout component
cat > src/pages/main-layout.tsx << 'EOF'
import { Outlet, useLocation } from '@modern-js/runtime/router';

export default function MainLayout() {
  const { pathname } = useLocation();

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header style={{ backgroundColor: '#212529', color: 'white', padding: '16px' }}>
        <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
          <h1 style={{ fontSize: '20px', fontWeight: 'bold', margin: 0 }}>Demo Shell</h1>
        </div>
      </header>
      <main>
        <Outlet />
      </main>
    </div>
  );
}
EOF

# Create home page
cat > src/pages/home.tsx << 'EOF'
export default function HomePage() {
  return (
    <div style={{ padding: '24px' }}>
      <div style={{ maxWidth: '800px', margin: '0 auto', textAlign: 'center' }}>
        <h1 style={{ fontSize: '48px', fontWeight: 'bold', marginBottom: '16px' }}>
          Welcome to Demo Shell
        </h1>
        <h3 style={{ fontSize: '32px', fontWeight: 'bold', marginBottom: '16px' }}>
          demo-shell
        </h3>
        <p style={{ fontSize: '18px', color: '#666', marginBottom: '32px', maxWidth: '500px', margin: '0 auto 32px' }}>
          A Modern.js micro-frontend shell ready for hosting multiple applications.
        </p>
        <div style={{ display: 'flex', gap: '16px', justifyContent: 'center', flexWrap: 'wrap' }}>
          <a 
            href="/customers" 
            style={{ 
              padding: '12px 24px', 
              backgroundColor: '#212529', 
              color: 'white', 
              borderRadius: '8px', 
              fontWeight: '500',
              textDecoration: 'none',
              display: 'inline-block'
            }}
          >
            View Customer App
          </a>
          <div style={{ 
            padding: '12px 16px', 
            border: '1px solid #ccc', 
            borderRadius: '8px', 
            fontWeight: '500'
          }}>
            Module Federation Demo
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

# Create basic styles directory (no Tailwind)
mkdir -p src/styles

cd ..

# Update app port to avoid conflict
log "${BLUE}Configuring MFE app port...${NC}"
cd "$APP_NAME"

# Ports are already configured in the archetype templates

cd ..

# Create Docker Compose file
log "${BLUE}Creating Docker Compose configuration...${NC}"
cat > docker-compose.yml << EOF
version: '3.8'

services:
  shell:
    build: ./$SHELL_NAME
    ports:
      - "3000:3000"
    depends_on:
      - customer-app
    environment:
      - NODE_ENV=production

  customer-app:
    build: ./$APP_NAME
    ports:
      - "3001:80"
    environment:
      - NODE_ENV=production

networks:
  default:
    driver: bridge
EOF

# Create development script
cat > run-dev.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting MFE Development Environment"
echo "======================================="

# Install dependencies in parallel
echo "📦 Installing dependencies..."
(cd demo-shell && pnpm install) &
(cd demo-customer-app && pnpm install) &
wait

# Start both applications
echo "🌐 Starting applications..."
echo "  Shell:        http://localhost:3000"
echo "  Customer App: http://localhost:3001"
echo "  Demo:         http://localhost:3000/customers"
echo ""

# Start customer app in background
(cd demo-customer-app && pnpm dev) &
CUSTOMER_PID=$!

# Start shell in foreground  
(cd demo-shell && pnpm dev) &
SHELL_PID=$!

# Wait for both processes
wait $CUSTOMER_PID $SHELL_PID
EOF

chmod +x run-dev.sh

# Create production script
cat > run-prod.sh << 'EOF'
#!/bin/bash
set -e

echo "🐳 Starting MFE Production Environment"
echo "======================================"
echo "Building and starting with Docker Compose..."
echo ""
echo "  Shell:        http://localhost:3000"
echo "  Customer App: http://localhost:3001"
echo "  Demo:         http://localhost:3000/customers"
echo ""

docker-compose up --build
EOF

chmod +x run-prod.sh

# Create README
cat > README.md << 'EOF'
# Modern.js Micro-Frontend Demo

This demo showcases a complete micro-frontend architecture using Modern.js and Module Federation.

## Architecture

```
┌─────────────────┐    ┌──────────────────────┐
│   Shell App     │    │   Customer App       │
│   (Port 3000)   │◄──►│   (Port 3001)        │
│                 │    │                      │
│ • Hosts MFEs    │    │ • Customer Management│
│ • Routing       │    │ • Exposed via MF     │
│ • Layout        │    │ • Independent Deploy │
└─────────────────┘    └──────────────────────┘
```

## Quick Start

### Development Mode
```bash
# Start both applications in development
./run-dev.sh
```

### Production Mode (Docker)
```bash
# Build and run with Docker Compose
./run-prod.sh
```

## Manual Development

```bash
# Terminal 1 - Customer App
cd demo-customer-app
pnpm install
pnpm dev  # Runs on port 3001 (configured in modern.config.ts)

# Terminal 2 - Shell App
cd demo-shell
pnpm install
pnpm dev  # Runs on port 3000 (configured in modern.config.ts)
```

## Access Points

- **Shell Application**: http://localhost:3000
- **Customer App (Standalone)**: http://localhost:3001
- **Integrated Demo**: http://localhost:3000/customers

## What This Demonstrates

✅ **Module Federation**: Customer app is loaded remotely into shell
✅ **Independent Development**: Apps can be developed separately
✅ **Shared Dependencies**: React, React DOM shared between apps
✅ **Routing Integration**: Shell routes to micro-frontend
✅ **Docker Deployment**: Production-ready containerization
✅ **Development Workflow**: Hot reload for both apps

## Generated Projects

- `demo-shell/` - Shell host application
- `demo-customer-app/` - Customer management micro-frontend
- `docker-compose.yml` - Production deployment configuration

## Stopping Services

```bash
# Development mode: Ctrl+C in terminal

# Production mode:
docker-compose down
```
EOF

log "${GREEN}✅ MFE Demo created successfully!${NC}"
log ""
log "${YELLOW}Demo directory structure:${NC}"
tree -L 2 . 2>/dev/null || ls -la

log ""
log "${GREEN}🚀 To start the demo:${NC}"
log "${BLUE}Development:${NC} ./run-dev.sh"
log "${BLUE}Production:${NC}  ./run-prod.sh"
log ""
log "${GREEN}🌐 Access points:${NC}"
log "  Shell:        http://localhost:3000"
log "  Customer App: http://localhost:3001" 
log "  Demo:         http://localhost:3000/customers"
