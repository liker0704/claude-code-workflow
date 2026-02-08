# Security Rules

## Secrets Management
- Never hardcode API keys, passwords, tokens, or credentials
- Always use environment variables for sensitive configuration
- Ensure .env files are in .gitignore
- Verify secrets are not logged or exposed in error messages
- Check for leaked credentials before committing code

## Injection Prevention
- Always use parameterized queries for database operations
- Never concatenate user input directly into SQL queries
- Validate and sanitize all user input before processing
- Escape user-generated content before rendering
- Use prepared statements for all database interactions

## Cross-Site Scripting (XSS)
- Sanitize all user-generated content before display
- Encode output based on context (HTML, JavaScript, URL)
- Use Content Security Policy headers
- Never insert unescaped user input into HTML
- Validate data types and formats from external sources

## Cross-Site Request Forgery (CSRF)
- Verify CSRF tokens on all state-changing requests
- Use SameSite cookie attributes
- Implement double-submit cookie pattern where applicable
- Check Origin and Referer headers for sensitive operations

## Authentication & Authorization
- Verify authentication before accessing protected resources
- Check authorization for every sensitive operation
- Never trust client-side authentication status
- Implement proper session management and timeouts
- Use secure password hashing (bcrypt, Argon2, scrypt)

## Path Traversal
- Validate all file paths before file operations
- Never allow user-controlled path components
- Use allowlists for permitted directories
- Reject paths containing "../" or absolute paths from users
- Canonicalize paths before validation

## Input Validation
- Validate all external input (APIs, forms, files, headers)
- Check data type, length, format, and range
- Use allowlists over denylists when possible
- Reject invalid input, don't try to sanitize everything
- Validate on server side, never trust client validation

## Error Handling
- Never expose stack traces to end users
- Log detailed errors internally only
- Return generic error messages to clients
- Handle all error cases explicitly
- Fail securely (deny by default)

## Dependency Security
- Check dependencies for known vulnerabilities regularly
- Keep dependencies updated to latest secure versions
- Remove unused dependencies
- Review security advisories for critical packages
- Use lock files to ensure consistent versions

## Data Protection
- Encrypt sensitive data at rest and in transit
- Use TLS/HTTPS for all network communication
- Implement proper access controls on data
- Sanitize data before deletion (avoid soft deletes of sensitive info)
- Minimize collection and retention of sensitive data
