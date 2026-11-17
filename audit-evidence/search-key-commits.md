# COMMIT ffaae21c228b35c1a6ff94d1a76c38c0f7fcd556
Restore unfiltered YouTube search request
@@ -75,7 +75,6 @@ enum YouTubeEngine {
                 "gl": "RU"
             ]],
             "query": query,
-            "params": "EgIQAQ=="
         ]
         let raw = try await post(searchURL, body: body, headers: [
             "Origin": "https://www.youtube.com",
