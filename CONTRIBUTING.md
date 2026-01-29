# Contributing to Decent Espresso Control

Thank you for your interest in contributing to the Decent Espresso Control project! This document provides guidelines for contributing to this open-source project.

## License Agreement

By contributing to this project, you agree that your contributions will be licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for the full license text.

## How to Contribute

### Reporting Bugs

1. Check if the issue already exists in the [GitHub Issues](https://github.com/BlipBloopBlopBlingBoop/deepdoopdop/issues)
2. If not, create a new issue with:
   - A clear, descriptive title
   - Steps to reproduce the problem
   - Expected vs actual behavior
   - Browser and device information
   - Screenshots if applicable

### Suggesting Features

1. Open a new issue with the "feature request" label
2. Describe the feature and its use case
3. Explain why this would benefit other users

### Submitting Code

1. **Fork the repository** and create a new branch from `main`
2. **Make your changes** following our coding standards
3. **Test your changes** thoroughly
4. **Commit with clear messages** describing what and why
5. **Submit a pull request** with a description of your changes

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/deepdoopdop.git
cd deepdoopdop

# Install dependencies
npm install

# Start development server
npm run dev

# Run linting
npm run lint

# Type check
npm run type-check

# Build for production
npm run build
```

## Coding Standards

### TypeScript/JavaScript

- Use TypeScript for all new code
- Follow existing code style and patterns
- Use meaningful variable and function names
- Add type annotations where helpful

### React Components

- Use functional components with hooks
- Keep components focused and reusable
- Follow the existing file structure

### CSS/Styling

- Use Tailwind CSS utility classes
- Follow the existing design system
- Ensure responsive design for mobile devices

### Commits

- Write clear, concise commit messages
- Use present tense ("Add feature" not "Added feature")
- Reference issue numbers when applicable

## Pull Request Process

1. Ensure your code passes all linting and type checks
2. Update documentation if needed
3. Add tests for new functionality when applicable
4. Request review from maintainers
5. Address any feedback promptly

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Accept responsibility for mistakes

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or insulting comments
- Personal or political attacks
- Publishing others' private information

## Safety Considerations

When contributing code that interacts with espresso machines:

- **Never bypass safety limits** defined by the machine
- **Test thoroughly** before submitting PRs involving machine control
- **Document any safety implications** of your changes
- **Follow the Decent protocol specifications** accurately

## Questions?

If you have questions about contributing, feel free to:

- Open a discussion on GitHub
- Ask in the Decent Espresso community forums
- Review existing pull requests for examples

Thank you for helping improve Decent Espresso Control!
