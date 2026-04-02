# Vitest Setup for Next.js DDD Projects

Reference for adding vitest to Next.js 16+ projects with DDD architecture.

## Installation

```bash
npm install -D vitest @vitejs/plugin-react @testing-library/react @testing-library/dom @testing-library/jest-dom jsdom
```

## Configuration

### vitest.config.ts

```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      include: ['src/domain/**'],
      exclude: [
        'src/domain/**/data/models/**',   // Pure types
        'src/domain/**/data/enums/**',     // Pure constants
      ],
    },
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, './src'),
    },
  },
})
```

### vitest.setup.ts

```typescript
import '@testing-library/jest-dom/vitest'
```

### package.json scripts

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage"
  }
}
```

## Test File Locations

Follow the DDD structure — colocate tests with source:

```
domain/{domain-name}/
├── data/
│   ├── infrastructure/__tests__/   # Service tests (mock HTTP)
│   ├── mappers/__tests__/          # Mapper unit tests
│   └── schemas/__tests__/          # Schema validation tests
├── feature/__tests__/              # Feature component tests
├── hooks/__tests__/                # Hook tests
└── utils/__tests__/                # Utility tests
```

## Test Templates

### Schema Validation Test

```typescript
import { describe, it, expect } from 'vitest'
import { mySchema, myRefinements } from '../mySchema'
import { z } from 'zod'

describe('mySchema', () => {
  it('accepts valid data', () => {
    const result = mySchema.safeParse({ name: 'Test', type: 1 })
    expect(result.success).toBe(true)
  })

  it('rejects missing required fields', () => {
    const result = mySchema.safeParse({})
    expect(result.success).toBe(false)
  })
})

describe('myRefinements', () => {
  it('requires name when type is special', () => {
    const ctx = { addIssue: vi.fn() } as unknown as z.RefinementCtx
    myRefinements({ type: MyEnum.Special, name: '' }, ctx)
    expect(ctx.addIssue).toHaveBeenCalledWith(
      expect.objectContaining({ path: ['name'] })
    )
  })
})
```

### Mapper Test

```typescript
import { describe, it, expect } from 'vitest'
import { toFormState, toRequest } from '../myMapper'

describe('myMapper', () => {
  it('maps API response to form state', () => {
    const apiData = { id: 1, name: 'Test' }
    const result = toFormState(apiData)
    expect(result).toEqual({ name: 'Test' })
  })

  it('maps form state to API request', () => {
    const formData = { name: 'Test' }
    const result = toRequest(formData)
    expect(result).toEqual({ name: 'Test' })
  })
})
```

### Service Test (with mocked HTTP)

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { myService } from '../myService'
import { apiService } from '@/domain/network/data/infrastructure/apiService'

vi.mock('@/domain/network/data/infrastructure/apiService', () => ({
  apiService: {
    inventoryHttp: {
      get: vi.fn(),
      post: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
    },
  },
}))

describe('myService', () => {
  beforeEach(() => vi.clearAllMocks())

  it('fetches list', async () => {
    const mockData = [{ id: 1, name: 'Test' }]
    vi.mocked(apiService.inventoryHttp.get).mockResolvedValue({ data: mockData })

    const result = await myService.getAll()
    expect(result).toEqual(mockData)
    expect(apiService.inventoryHttp.get).toHaveBeenCalledWith('/endpoint')
  })
})
```

### Component Test

```typescript
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import MyComponent from '../MyComponent'

// Mock Next.js modules as needed
vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useParams: () => ({}),
}))

describe('MyComponent', () => {
  it('renders title', () => {
    render(<MyComponent title="Test" />)
    expect(screen.getByText('Test')).toBeInTheDocument()
  })
})
```

## What to Test (Priority)

High-value, low-effort test targets in DDD projects:

1. **Zod schemas** — pure validation logic, easy to test
2. **Mappers** — pure data transformations, easy to test
3. **Utility functions** — pure logic in `utils/`
4. **Service methods** — API call structure with mocked HTTP
5. **Complex hooks** — hooks with business logic (use `renderHook`)
6. **Feature components** — critical user flows only

Skip testing:
- Pure type definitions (models, enums)
- Simple pass-through components
- DaisyUI styling details
