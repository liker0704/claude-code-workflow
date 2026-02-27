# Performance Rules

## Model Selection Strategy
- Use Haiku for simple worker tasks (formatting, linting, data extraction, simple transformations)
- Use Sonnet for moderate tasks (code review, refactoring, standard implementation)
- Use Opus for complex reasoning (architecture decisions, deep analysis, multi-step problem solving)
- Match model cost to task complexity
- Don't over-provision models for trivial operations

## Caching Strategy
- Cache expensive computations and their results
- Memoize pure functions with stable inputs
- Use appropriate cache invalidation strategies
- Cache at the right level (function, module, system)
- Consider cache size limits and eviction policies
- Cache compiled templates and patterns

## Query Optimization
- Avoid N+1 query problems
- Use batch operations for multiple related queries
- Fetch only required fields (select specific columns)
- Use indexes on frequently queried fields
- Paginate large result sets
- Consider query result caching for expensive operations

## Lazy Loading
- Load resources only when needed
- Defer initialization of expensive objects
- Use pagination for large datasets
- Stream large files instead of loading entirely
- Implement on-demand imports/requires
- Avoid loading unused features upfront

## File I/O Optimization
- Minimize disk operations (batch reads/writes)
- Use buffered I/O for sequential access
- Read files once and cache if used multiple times
- Use streaming for large files
- Close file handles promptly
- Batch write operations when possible

## Algorithm Efficiency
- Choose appropriate data structures for the task
- Consider time and space complexity
- Avoid unnecessary iterations over data
- Use early returns to skip unnecessary work
- Profile before optimizing
- Optimize hot paths, not cold code

## Network Efficiency
- Batch API calls when possible
- Use connection pooling
- Implement request timeouts
- Cache responses when appropriate
- Use compression for large payloads
- Parallelize independent network operations

## Memory Management
- Release resources when no longer needed
- Avoid memory leaks (clear references, close connections)
- Stream large datasets instead of loading into memory
- Use generators/iterators for large sequences
- Monitor memory usage in long-running processes
- Clear caches periodically if unbounded

## Concurrency
- Use asynchronous operations for I/O-bound tasks
- Parallelize independent operations
- Avoid blocking operations in critical paths
- Use appropriate concurrency primitives
- Be mindful of race conditions
- Don't over-parallelize (overhead vs benefit)

## Premature Optimization
- Measure before optimizing
- Focus on bottlenecks, not assumptions
- Keep code readable unless performance critical
- Document performance-critical sections
- Use profiling tools to identify real issues
- Optimize for maintainability first, then performance
