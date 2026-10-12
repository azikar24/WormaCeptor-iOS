#if DEBUG
import Foundation
import WormaCeptor

extension PreviewSamples {
    static let jsonBody = """
    {
      "id": 1042,
      "status": "shipped",
      "paid": true,
      "coupon": null,
      "items": [
        {
          "sku": "TEE-001",
          "qty": 2,
          "price": 19.5
        },
        {
          "sku": "CAP-207",
          "qty": 1,
          "price": 12
        }
      ],
      "tags": [],
      "customer": {
        "id": "c_88",
        "email": "ana@example.com"
      }
    }
    """

    static let detailRich = WormaCeptorTransactionDetail(
        id: "2",
        method: "POST",
        url: "https://api.example.com/v1/orders/1042/fulfilment?expand=items&locale=en",
        host: "api.example.com",
        path: "/v1/orders/1042/fulfilment",
        statusCode: KotlinInt(int: 201),
        statusMessage: "Created",
        tone: .success,
        durationMs: KotlinLong(longLong: 733),
        timestampMs: now,
        isMocked: true,
        error: nil,
        protocol: "h2",
        tlsVersion: "TLSv1.3",
        request: WormaCeptorMessage(
            headers: [
                WormaCeptorHeader(name: "Accept", value: "application/json"),
                WormaCeptorHeader(name: "Authorization", value: "Bearer eyJhbGciOiJIUzI1NiJ9.e30"),
                WormaCeptorHeader(name: "Content-Type", value: "application/json"),
            ],
            body: "{\n  \"carrier\": \"ups\",\n  \"notify\": true\n}",
            bodySize: 34,
            contentType: "application/json",
            isJson: true,
            isBodyTruncated: false
        ),
        response: WormaCeptorMessage(
            headers: [
                WormaCeptorHeader(name: "Cache-Control", value: "no-store"),
                WormaCeptorHeader(name: "Content-Type", value: "application/json; charset=utf-8"),
                WormaCeptorHeader(name: "Set-Cookie", value: "a=1"),
                WormaCeptorHeader(name: "Set-Cookie", value: "b=2"),
            ],
            body: jsonBody,
            bodySize: 1_536,
            contentType: "application/json; charset=utf-8",
            isJson: true,
            isBodyTruncated: false
        )
    )

    static let detailFailed = WormaCeptorTransactionDetail(
        id: "3",
        method: "GET",
        url: "http://httpbin.org/delay/10",
        host: "httpbin.org",
        path: "/delay/10",
        statusCode: nil,
        statusMessage: nil,
        tone: .error,
        durationMs: KotlinLong(longLong: 10_000),
        timestampMs: now,
        isMocked: false,
        error: "The request timed out.",
        protocol: nil,
        tlsVersion: nil,
        request: WormaCeptorMessage(
            headers: [],
            body: nil,
            bodySize: 0,
            contentType: nil,
            isJson: false,
            isBodyTruncated: false
        ),
        response: nil
    )
}
#endif
