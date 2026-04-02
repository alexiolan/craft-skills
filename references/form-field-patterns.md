# Form Field Patterns

Reference for TanStack React Form + Zod + DaisyUI field architecture used across DDD frontend projects.

## Architecture Overview

```
forms/
├── data/
│   ├── contexts/contexts.tsx    # createFormHookContexts() — shared field/form contexts
│   └── models/forms.ts          # Option, OptionType types
├── fields/
│   ├── utils/
│   │   ├── FieldContainer.tsx   # Base wrapper (label, error, prefix/suffix/tips)
│   │   ├── FieldLabel.tsx
│   │   └── FieldError.tsx
│   ├── TextField.tsx            # text, email, tel, url
│   ├── TextAreaField.tsx
│   ├── NumberField.tsx
│   ├── NumberWithCurrencyField.tsx
│   ├── PasswordField.tsx
│   ├── RadioField.tsx
│   ├── SelectField.tsx          # Native select with type coercion
│   ├── SearchableSelectField.tsx # Async search + select with debounce
│   ├── SearchableMultiselectField.tsx
│   ├── MultiselectField.tsx
│   ├── TreeviewMultiselectField.tsx
│   ├── CheckboxField.tsx
│   ├── ToggleField.tsx
│   ├── ColorPickerField.tsx
│   ├── DateField.tsx
│   ├── DateRangeField.tsx
│   ├── WysiwygField.tsx
│   ├── DropzoneField.tsx        # File upload with preview
│   └── SubmitButton.tsx
├── hooks/
│   └── useAppForm.ts            # createFormHook() — registers all fields
└── ui/
    ├── DatePicker.tsx
    ├── DateRangePicker.tsx
    └── DropzoneInput.tsx
```

## Core Pattern: Hook Registration

All field components are registered once in `useAppForm.ts` via `createFormHook()`:

```typescript
import { createFormHook } from '@tanstack/react-form'

export const { useAppForm, withForm, withFieldGroup } = createFormHook({
  fieldComponents: { TextField, SelectField, ... },
  formComponents: { SubmitButton },
  fieldContext,
  formContext,
})
```

This enables the render-prop pattern in features:

```tsx
const form = useAppForm({ defaultValues, validators, onSubmit })

<form.AppField name="city">
  {field => <field.TextField label="City" placeholder="Enter city" />}
</form.AppField>

<form.AppForm>
  <SubmitButton label="Save" />
</form.AppForm>
```

## Base Field Interface

All fields extend `FieldProps`:

```typescript
interface FieldProps {
  label?: string
  tips?: string          // Tooltip icon with hover text
  fullWidth?: boolean    // Default: true
  className?: string
  suffix?: string        // Right-side label inside input
  prefix?: string        // Left-side label inside input
  readonly?: boolean
  error?: string         // External error message
}
```

Fields access form state via `useFieldContext<T>()` from the shared context.

## Validation Pattern

Three-part schema pattern per domain:

```typescript
// 1. Schema definition
export const mySchema = z.object({
  name: z.string(),
  type: z.nativeEnum(MyEnum),
})

// 2. Default values
export const myDefaults = {
  name: '',
  type: MyEnum.Default,
}

// 3. Refinements for cross-field validation
export function myRefinements(data: {...}, ctx: z.RefinementCtx): void {
  if (data.type === MyEnum.Special && !data.name) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, message: '...', path: ['name'] })
  }
}
```

Hook usage with validation:

```tsx
const form = useAppForm({
  defaultValues: myDefaults,
  validators: { onChange: mySchema },
  onSubmit: async ({ value }) => { ... },
})
```

## Select Field Type Coercion

`SelectField` auto-coerces string values from `<select>`:
- `"true"` / `"false"` → boolean
- Numeric strings → number
- Everything else → string

`Option` type: `{ value: string | number | boolean | null; label: string }`

## Complex Field Patterns

**SearchableSelectField** — async search with debounce:
- Manages `userTypedQuery` local state separately from form state
- 300ms debounce on search callback
- `minSearchLength` threshold (default: 2)
- Uses shared `Dropdown` component with portal rendering

**DropzoneField** — file upload:
- Stores `File | null` in form state
- Accepts MIME type config (`accept`) and size limits (`maxSize`)
- Omits `suffix`/`prefix` from base FieldProps

## Decision Flow

```
Need a form input?
  → Does an existing field handle this? → Use it via form.AppField
  → Almost, but needs a small tweak? → Extend the existing field's props
  → Fundamentally different input type? → Create new field, register in useAppForm.ts
```

## DaisyUI Integration

- Input classes: `input`, `input-bordered`, `input-error`, `input-success`
- Select classes: `select`, `select-error`, size variants (`select-xs` to `select-xl`)
- Validation: `validator` class + `aria-invalid` attribute
- Layout: `FieldContainer` handles conditional rendering based on prefix/suffix/tips
