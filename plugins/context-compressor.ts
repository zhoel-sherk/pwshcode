// context-compressor.ts — opencode plugin
// Inline PAKT (Pipe-Aligned Kompact Text) compressor for structured data.
// Zero external dependencies. Only imports the Plugin type (erased at runtime).
// Original PAKT concept: https://github.com/sriinnu/clipforge-PAKT
//
// Env vars:
//   CONTEXT_COMPRESSOR_THRESHOLD — min token count to compress (default: 200)

import type { Plugin } from "@opencode-ai/plugin"

// ─── Config ──────────────────────────────────────────────────

const THRESHOLD = (() => {
  const v = Number(process.env.CONTEXT_COMPRESSOR_THRESHOLD)
  return Number.isFinite(v) && v >= 0 ? v : 200
})()

// ─── Detect format ───────────────────────────────────────────

function detectFormat(input: string): string {
  const trimmed = input.trim()
  if (!trimmed) return "plain"

  const lines = trimmed.split("\n").filter(Boolean)
  if (lines.length === 0) return "plain"

  // JSON — starts with { or [
  const first = lines[0].trim()
  if ((first.startsWith("{") && trimmed.endsWith("}")) ||
      (first.startsWith("[") && trimmed.endsWith("]"))) {
    try { JSON.parse(trimmed); return "json" } catch { /* fallthrough */ }
  }

  // CSV — header with commas, matching column count
  if (lines.length >= 2) {
    const hdr = lines[0].split(",")
    if (hdr.length >= 2) {
      const cols = hdr.length
      const allMatch = lines.slice(1).every(l => l.split(",").length === cols)
      if (allMatch && !lines[0].includes(":")) return "csv"
    }
  }

  // YAML — key: value pairs (no JSON structure)
  if (lines.some(l => /^\w[\w-]*:\s/.test(l)) &&
      !lines.some(l => l.includes("{") || l.includes("["))) {
    return "yaml"
  }

  // Markdown — headers, formatting, or pipe tables
  if (/^#/.test(first) || trimmed.includes("**") || trimmed.includes("[") ||
      lines.some(l => l.trim().startsWith("|") && l.trim().endsWith("|"))) {
    return "md"
  }

  return "plain"
}

// ─── Compressors ─────────────────────────────────────────────

interface CompressResult {
  compressed: string
  format: string
  saved: number
  original: string
}

function compressJson(input: string, raw: string): CompressResult {
  const parsed = JSON.parse(input)
  const items = Array.isArray(parsed) ? parsed : [parsed]
  if (items.length === 0) return { compressed: raw, original: raw, format: "json", saved: 0 }

  const keys = [...new Set(items.flatMap(Object.keys))]
  if (keys.length === 0) return { compressed: raw, original: raw, format: "json", saved: 0 }
  const header = keys.join("|")

  const rows: string[][] = items.map(item => keys.map(k => String(item[k] ?? "")))
  const valFreq = new Map<string, number>()
  for (const row of rows) {
    for (const v of row) {
      if (v.length > 1) valFreq.set(v, (valFreq.get(v) ?? 0) + 1)
    }
  }

  const dict = new Map<string, string>()
  let di = 0
  for (const [v, c] of valFreq) {
    if (c >= 2 && di < 52) {
      dict.set(v, di < 26 ? "$" + String.fromCharCode(97 + di) : "$" + String.fromCharCode(65 + di - 26))
      di++
    }
  }

  let out = "@from json\n"
  if (dict.size > 0) {
    out += "@dict\n"
    for (const [v, a] of dict) out += `${a}: ${v}\n`
    out += "@end\n"
  }
  out += header + ":\n"
  for (const row of rows) {
    out += row.map(v => dict.get(v) ?? v).join("|") + "\n"
  }

  const c = out.trimEnd()
  return { compressed: c, original: raw, format: "json", saved: raw.length - c.length }
}

function compressCsv(input: string, raw: string): CompressResult {
  const lines = input.split("\n")
  if (lines.length < 2) return { compressed: raw, original: raw, format: "csv", saved: 0 }

  const hdr = lines[0].split(",").map(h => h.trim()).join("|")
  let out = "@from csv\n" + hdr + ":\n"
  for (let i = 1; i < lines.length; i++) {
    const v = lines[i].trim()
    if (v) out += v.split(",").map(x => x.trim()).join("|") + "\n"
  }

  const c = out.trimEnd()
  return { compressed: c, original: raw, format: "csv", saved: raw.length - c.length }
}

function compressMd(input: string, raw: string): CompressResult {
  let result = input
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/\*(.+?)\*/g, "$1")
    .replace(/`(.+?)`/g, "$1")
    .replace(/~~(.+?)~~/g, "$1")
    .replace(/\[(.+?)\]\(.+?\)/g, "$1")
    .replace(/^#{1,6}\s+/gm, "")
    .replace(/^[\s]*[-*+]\s+/gm, "")
    .replace(/^>\s+/gm, "")

  // PAKT-ify tables
  const lines = result.split("\n")
  let ti = -1
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim().startsWith("|") && lines[i].trim().endsWith("|")) {
      ti = i; break
    }
  }
  if (ti >= 0 && ti + 1 < lines.length && /^\|[\s:\-|]+\|$/.test(lines[ti + 1].trim())) {
    const hdr = lines[ti].trim().split("|").filter(Boolean).map(h => h.trim()).join("|")
    const dataLines: string[] = []
    let di = ti + 2
    while (di < lines.length && lines[di].trim().startsWith("|")) {
      dataLines.push(lines[di].trim().split("|").filter(Boolean).map(x => x.trim()).join("|"))
      di++
    }
    if (dataLines.length > 0) {
      const table = "@from md\n" + hdr + ":\n" + dataLines.join("\n")
      result = [...lines.slice(0, ti), table, ...lines.slice(di)].join("\n")
    }
  }

  const c = result.trimEnd()
  return { compressed: c, original: raw, format: "md", saved: raw.length - c.length }
}

// ─── Main compress / decompress ──────────────────────────────

function paktCompress(input: string): CompressResult | null {
  const format = detectFormat(input)
  if (format === "plain" || format === "yaml") return null

  const norm = input.replace(/\r\n/g, "\n")
  switch (format) {
    case "json": return compressJson(norm, input)
    case "csv":  return compressCsv(norm, input)
    case "md":   return compressMd(norm, input)
    default:     return null
  }
}

function paktDecompress(input: string): string {
  const stripped = input.replace(/^\[PAKT@\w+\]\s*/m, "").trim()
  if (!stripped.startsWith("@from")) return input

  const lines = stripped.split("\n")
  const fmt = (lines[0].match(/@from\s+(\w+)/)?.[1] ?? "") as "json" | "csv" | "md"

  // Build dict
  const dict = new Map<string, string>()
  let li = 1
  if (lines[li]?.trim() === "@dict") {
    li++
    while (li < lines.length && lines[li].trim() !== "@end") {
      const m = lines[li].match(/^\$(\w):\s*(.+)/)
      if (m) dict.set("$" + m[1], m[2])
      li++
    }
    li++ // skip @end
  }

  // Parse data
  if (li >= lines.length) return input
  const fields = lines[li].replace(/:$/, "").split("|")
  li++

  const rows: string[][] = []
  while (li < lines.length) {
    const v = lines[li].trim()
    if (v) {
      rows.push(v.split("|").map(c => dict.get(c) ?? c))
    }
    li++
  }

  if (rows.length === 0) return input

  if (fmt === "json") {
    const result = rows.map(r => {
      const obj: Record<string, string> = {}
      fields.forEach((f, i) => { obj[f] = r[i] ?? "" })
      return obj
    })
    return JSON.stringify(result.length === 1 ? result[0] : result, null, 2)
  }

  if (fmt === "csv") {
    return [fields.join(","), ...rows.map(r => r.join(","))].join("\n")
  }

  // md
  const sep = "|" + fields.map(() => "---").join("|") + "|"
  return [
    "|" + fields.join("|") + "|",
    sep,
    ...rows.map(r => "|" + r.join("|") + "|")
  ].join("\n")
}

// ─── Token estimate ──────────────────────────────────────────

function estimateTokens(s: string): number {
  return Math.ceil(s.length / 4)
}

// ─── Plugin hooks ────────────────────────────────────────────

export default (async () => {
  return {
    "tool.execute.after": async (_input: unknown, output: Record<string, unknown>) => {
      try {
        const content = String(output.content ?? output.result ?? "")
        if (!content || content.length < 20) return
        if (estimateTokens(content) < THRESHOLD) return

        const r = paktCompress(content)
        if (!r || r.saved <= 10) return

        const marker = `[PAKT@${r.format}]\n`

        if (output.content !== undefined) {
          output.content = marker + r.compressed
        } else if (output.result !== undefined) {
          output.result = marker + r.compressed
        }
      } catch {
        // silent — never break tool output
      }
    },

    "experimental.chat.messages.transform": async (messages: Array<Record<string, unknown>>) => {
      for (const msg of messages) {
        if (msg.role !== "tool") continue
        const content = String(msg.content ?? "")
        if (!content || content.length < 20) continue
        if (content.startsWith("[PAKT@")) continue // already compressed
        if (estimateTokens(content) < THRESHOLD) continue

        try {
          const r = paktCompress(content)
          if (r && r.saved > 10) {
            msg.content = `[PAKT@${r.format}]\n${r.compressed}`
          }
        } catch {
          // silent
        }
      }
      return messages
    },

    "experimental.chat.system.transform": async (system: string) => {
      const hint = [
        "",
        "## PAKT Context Compression",
        "",
        "Tool outputs may contain PAKT-encoded data for token efficiency.",
        "PAKT is lossless and self-describing:",
        "- `@from json|csv|md` — source format",
        "- `@dict ... @end` — value aliases ($a, $b, ...)",
        "- `field1|field2: val1|val2` — pipe-delimited records",
        "",
        "Read PAKT directly. If you need the original byte-for-byte, call the `decompress` tool.",
        ""
      ].join("\n")
      return system + hint
    },

    tool: {
      decompress: {
        name: "decompress",
        description: "Decompress PAKT-encoded content back to original. Pass the content starting with [PAKT@ or @from.",
        input_schema: {
          type: "object",
          properties: {
            content: { type: "string", description: "PAKT content to decompress" }
          },
          required: ["content"]
        },
        handler: async ({ content }: { content: string }) => {
          try {
            return paktDecompress(content)
          } catch (e) {
            return `Decompress error: ${e}`
          }
        }
      }
    }
  }
}) satisfies Plugin
