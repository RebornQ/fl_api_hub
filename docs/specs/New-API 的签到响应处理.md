New-API 的签到响应处理有问题，目前已知的签到响应：
```javascript
{"message":"今日已签到","success":false}

{"data":{"checkin_date":"2026-04-23","quota_awarded":1083226},"message":"签到成功","success":true}
```

跟代码中转换的 `CheckInResultDto` 字段不一致，可能导致了转换失败，导致 `CheckInNotifier`  的 `executeCheckIn`  中  `CheckInResultDto`  实例 `dto.message` 数据为 null

可参考 JS 代码：
```javascript
/**
 * Check-in result status
 */
export const CHECKIN_RESULT_STATUS = {
  SUCCESS: "success",
  ALREADY_CHECKED: "already_checked",
  FAILED: "failed",
  SKIPPED: "skipped",
} as const

export interface CheckinRecord {
  /**
   * 签到日期，格式 YYYY-MM-DD
   * @example "2026-01-03"
   */
  checkin_date: string
  quota_awarded: number
}

/**
 * New-API 签到响应类型
 */
export type NewApiCheckinResponse = {
  data: CheckinRecord
  success: boolean
  /**
   * Response message from the API.
   * @example "签到成功"
   * @example "今日已签到"
   * @example "签到失败，请稍后重试"
   * @example "签到失败：更新额度出错"
   */
  message: string
}

/**
 * Normalize a New-API check-in payload into the provider result for the common
 * success/already-checked outcomes.
 *
 * Returns `null` when the payload doesn't match those outcomes so the caller
 * can fall back to Turnstile/manual-required handling.
 */
function resolveStandardCheckinResult(params: {
  payload: NewApiCheckinResponse | undefined
  message?: string
}): CheckinResult | null {
  const payload = params.payload
  if (!payload) return null

  const message = params.message ?? normalizeCheckinMessage(payload.message)

  if (message && isAlreadyCheckedMessage(message) && !payload.success) {
    return {
      status: CHECKIN_RESULT_STATUS.ALREADY_CHECKED,
      rawMessage: message || undefined,
      data: payload.data,
    }
  }

  if (payload.success) {
    return {
      status: CHECKIN_RESULT_STATUS.SUCCESS,
      rawMessage: message || undefined,
      messageKey: message
        ? undefined
        : AUTO_CHECKIN_PROVIDER_FALLBACK_MESSAGE_KEYS.checkinSuccessful,
      data: payload.data ?? undefined,
    }
  }

  return null
}
```

请修复问题