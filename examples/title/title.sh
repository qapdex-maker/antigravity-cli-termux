#!/bin/bash
set -euo pipefail

jq -r '
  def safe_get(key): if type == "object" then .[key] else null end;
  def safe_nested(parent_key; child_key): if (type == "object") and (.[parent_key] | type == "object") then .[parent_key][child_key] else null end;
  def titlecase: (tostring | split("_") | join(" ") | (.[0:1] | ascii_upcase) + .[1:]);

  def trunc_str:
    if (type == "string") and (length > 15) then
      .[0:9] + "..." + .[-3:]
    else
      .
    end;

  def parse_workspace:
    (safe_nested("workspace"; "current_dir") // "") as $cwd |
    (if ($cwd | type == "string") and ($cwd != "") then
      if ($cwd | startswith("/google/src/cloud/")) then
        ($cwd[18:] | split("/") | if length > 1 then .[1] else null end)
      else
        null
      end // ($cwd | split("/") | map(select(. != "")) | if length > 0 then .[-1] else "/" end)
    else
      "unknown"
    end) as $ws |
    if ($ws | type == "string") and ($ws | test("^[a-zA-Z0-9_./\\ -]+$")) then $ws else "unknown" end;

  (safe_get("agent_state") // "idle") as $st |
  (if $st == "initializing" then ["🚀", "Initializing"]
   elif $st == "idle" then ["🟢", "Idle"]
   elif $st == "thinking" then ["🤔", "Thinking"]
   elif ($st == "planning" or $st == "plan") then ["📋", "Planning"]
   elif $st == "working" then ["🏃", "Working"]
   elif $st == "tool_use" then ["🔧", "Using Tool"]
   elif $st == "review" then ["👀", "Review"]
   elif $st == "paused" then ["⏸️", "Paused"]
   elif ($st == "waiting" or $st == "input_required" or $st == "permission_required" or $st == "prompt" or $st == "approval_required" or $st == "approval" or $st == "permission" or $st == "confirm" or $st == "confirmation") then ["❓", "Waiting for Input"]
   elif ($st == "compacting" or $st == "context_compacting" or $st == "summarizing") then ["🧹", "Compacting"]
   elif ($st == "retry" or $st == "retrying") then ["🔄", "Retrying"]
   elif ($st == "completed" or $st == "success") then ["✅", "Completed"]
   elif ($st == "failed" or $st == "error") then ["❌", "Failed"]
   elif $st == "cancelled" then ["🛑", "Cancelled"]
   elif ($st == "stopped" or $st == "interrupted") then ["🛑", "Stopped"]
   elif $st == "aborted" then ["🛑", "Aborted"]
   else ["🤖", ($st | titlecase)]
   end) as $res |

  ($res[0]) as $emoji |
  ($res[1] | if test("^[a-zA-Z0-9_\\ -]+$") then . else "Idle" end) as $label |
  parse_workspace as $ws |
  (safe_nested("sandbox"; "enabled") == true) as $sb |
  (safe_nested("model"; "display_name") // "") as $raw_model |
  (if ($raw_model | type == "string") and ($raw_model | test("^[a-zA-Z0-9_./\\ -]+$")) then $raw_model else "" end) as $model |
  (safe_nested("vcs"; "branch") // "") as $raw_branch |
  (if ($raw_branch | type == "string") and ($raw_branch | test("^[a-zA-Z0-9_./-]+$")) then $raw_branch else "" end) as $branch |
  (safe_nested("vcs"; "dirty") == true) as $dirty |

  (if $model != "" then " (🧠 " + ($model | trunc_str) + ")" else "" end) as $m_txt |
  (if $branch != "" then " (🌿 " + ($branch | trunc_str) + (if $dirty then "*" else "" end) + ")" else "" end) as $vcs_txt |
  (if $sb then " (🔒 Sandbox ON)" else " (🔓 Sandbox OFF)" end) as $sb_txt |

  $emoji + " " + $label + " | " + $ws + $m_txt + $vcs_txt + $sb_txt
' 2>/dev/null || echo "🤖 Idle | unknown (🔓 Sandbox OFF)"
