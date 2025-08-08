# TypeScript Modern.js MFE App Archetype

![Latest Release](https://img.shields.io/github/v/release/p6m-archetypes/typescript-modernjs-mfe-app.archetype?style=flat-square&label=Latest%20Release&color=blue)

This is an [Archetect](https://archetect.github.io/) archetype for building Modern.js micro frontend applications that can be consumed by MFE shell hosts using Module Federation.

## Features

- **Modern.js Framework**: Built on the latest Modern.js framework with Rspack bundling
- **Module Federation**: Pre-configured to expose components and routes as federated modules
- **TypeScript**: Full TypeScript support for type safety and enhanced developer experience
- **Micro Frontend App**: Designed as a standalone MFE app that can be integrated into shell hosts
- **Docker Ready**: Includes optimized Dockerfile for containerized deployments
- **Kubernetes Compatible**: Configured for seamless deployment on Kubernetes clusters
- **Biome**: Pre-configured code quality and formatting tools
- **Modern Routing**: Uses Modern.js file-based routing with the `routes/` directory structure

## Rendering

To generate content from this Archetype, copy and execute the following command:

```sh
archetect render git@github.com:p6m-archetypes/typescript-modernjs-mfe-app.archetype.git#v1
```

## 🚀 Complete MFE Demo

Want to see this archetype in action with a shell host? Use the included demo script:

```bash
# Download and run the demo creation script
curl -sSL https://raw.githubusercontent.com/p6m-archetypes/typescript-modernjs-mfe-app.archetype/main/create_mfe_demo.sh | bash

# Or clone the repo and run locally
git clone https://github.com/p6m-archetypes/typescript-modernjs-mfe-app.archetype.git
cd typescript-modernjs-mfe-app.archetype
./create_mfe_demo.sh
```

**What the demo creates:**
- Shell host application (port 3000)
- Customer management MFE app (port 3001) 
- Module Federation integration
- Docker Compose for production deployment
- Development and production scripts

**Demo access points:**
- Shell: http://localhost:3000
- Customer App: http://localhost:3001
- Integrated Demo: http://localhost:3000/customers
