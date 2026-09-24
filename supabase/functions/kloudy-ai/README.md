# Kloudy AI function

This function keeps the model credential off mobile devices and only accepts requests with a valid signed-in user session.

Before deploying, add `ANTHROPIC_API_KEY` to the project's Edge Function secrets. `SUPABASE_URL` and `SUPABASE_ANON_KEY` are supplied by the function runtime.

Deploy with:

```sh
supabase functions deploy kloudy-ai
```

The Flutter app calls this function for chat, home insights, reflections, and food image analysis. Local demo sessions continue to use the lightweight on-device responses and do not call this function.
