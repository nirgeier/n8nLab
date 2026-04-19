# MkDocs Labs Documentation

* A comprehensive collection of hands-on labs for learning and mastering MkDocs documentation skills. 
* These labs provide practical exercises covering MkDocs fundamentals, advanced concepts, and real-world scenarios.

## Overview

* This documentation site contains a series of progressive labs designed to take you from MkDocs basics to advanced documentation techniques. 
* Each lab builds upon the previous one, ensuring a structured learning path.

---

## 🚀 Lab Series [Example]

| Lab | Title | Description |
|-----|-------|-------------|
| 000 | [Setup](./000-setup/) | Environment setup and prerequisites |
| 001 | [Basic MkDocs Site](./001-basic-mkdocs/) | Creating your first MkDocs site |
| 002 | [MkDocs Configuration](./002-mkdocs-config/) | Understanding configuration files |
| 003 | [MkDocs Theme](./003-mkdocs-theme/) | Customizing themes and appearance |
| 004 | [MkDocs Extra Features](./004-mkdocs-extra/) | Adding extra features and social links |
| 005 | [MkDocs Plugins](./005-mkdocs-plugins/) | Extending functionality with plugins |
| 006 | [MkDocs Extensions](./006-mkdocs-extensions/) | Markdown extensions and enhancements |
| 007 | [MkDocs Navigation](./007-mkdocs-nav/) | Building navigation structures |
| 008 | [MkDocs Deployment](./008-mkdocs-deployment/) | Deploying to GitHub Pages and other platforms |
| 009 | [Advanced Customization](./009-advanced-custom/) | Theme overrides and custom CSS/JS |
| 010 | [MkDocs Best Practices](./010-mkdocs-best-practices/) | Optimization and maintenance |
| 011 | [Real-World Projects](./011-real-world/) | Building complete documentation sites |

## 📁 Project Structure

```text
📂 mkdocs                         # Root project directory
 ┣ 📄 README.md                   # Project documentation
 ┣ 📄 vercel.json                 # Vercel deployment configuration
 ┣ 📦 requirements.txt            # Python dependencies (in mkdocs/)
 ┣ 📝 mkdocs.yml                  # Main MkDocs configuration
 ┣ 📂 Labs                        # Documentation content directory
 ┃ ┣ 📄 index.md                  # This file - labs overview
 ┃ ┗ 📄 welcome.md                 # Welcome page
 ┣ 📂 mkdocs                      # Modular configuration files
 ┃ ┣ 📝 01-mkdocs-site.yml        # Basic site configuration
 ┃ ┣ 🎨 02-mkdocs-theme.yml       # Material theme settings
 ┃ ┣ ➕ 03-mkdocs-extra.yml       # Extra features and social links
 ┃ ┣ 🔌 04-mkdocs-plugins.yml     # Plugin configurations
 ┃ ┣ 🧩 05-mkdocs-extensions.yml  # Markdown extensions
 ┃ ┣ 📑 06-mkdocs-nav.yml         # Navigation structure
 ┃ ┣ 📋 mkdocs.yml.schema.json    # Configuration schema
 ┃ ┣ 📂 overrides                 # Theme customizations
 ┃ ┃ ┣ 🧩 home.html               # Custom homepage
 ┃ ┃ ┣ 📂 assets                  # Custom assets
 ┃ ┃ ┣ 📂 partials                # Custom partial templates
 ┃ ┃ ┗ 📂 stylesheets             # Custom styles
 ┃ ┗ 📂 scripts                   # Utility scripts
 ┃   ┣ 🛠️ build_nav.sh            # Navigation builder
 ┃   ┣ 🛠️ build-multiarch.sh      # Multi-architecture build
 ┃   ┣ 🛠️ init_site.sh            # Site initialization
 ┃   ┗ 🛠️ init_vercel.sh          # Vercel setup
 ┗ 📂 mkdocs-site                 # Built site (generated)
   ┣ 📄 index.html                # Main page
   ┣ 📄 404.html                  # Error page
   ┣ 📄 sitemap.xml               # Site map
   ┣ 📂 assets                    # Site assets
   ┣ 📂 css                       # Custom CSS
   ┣ 📂 js                        # Custom JavaScript
   ┣ 📂 print_page                # Print-friendly pages
   ┗ 📂 search                    # Search index
```

## 🛠️ Getting Started with MkDocs Labs

### Prerequisites

Before starting these labs, ensure you have:

- A Python 3.8+ environment
- MkDocs installed (`uv pip install mkdocs`)
- Basic knowledge of Markdown
- Git for version control
- A text editor or IDE

### How to Use These Labs

1. **Start with Lab 000**: Set up your environment
2. **Follow the sequence**: Each lab builds on the previous one
3. **Read the instructions**: Each lab folder contains a README.md with detailed steps
4. **Practice hands-on**: Don't just read - build the sites and experiment
5. **Experiment**: Modify the configurations to understand how they work

### Running the Labs

Most labs can be run locally:

- Use `mkdocs serve` to preview your site
- Use `mkdocs build` to generate static files
- Deploy to GitHub Pages with `mkdocs gh-deploy`
- Or use any static hosting service

## 📚 Learning Objectives

By completing these labs, you will learn:

- MkDocs installation and configuration
- Theme customization and styling
- Plugin integration and usage
- Markdown extensions and advanced features
- Navigation and site structure
- Deployment strategies and automation
- Best practices for documentation sites

## 🤝 Contributing to Labs

Found an issue or want to improve a lab?

1. Fork the [mkdocs repository](https://github.com/nirgeier/mkdocs)
2. Create your feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

Need help with the labs?

- Check the [MkDocs documentation](https://www.mkdocs.org/)
- Join our [Discord community](https://discord.gg/U6xW23Ss)
- Open an issue in the [GitHub repository](https://github.com/nirgeier/mkdocs)

---

**Happy documenting with MkDocs!*
