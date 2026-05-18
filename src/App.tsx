import { RecipeCard } from "@/components/RecipeCard";
import { Button } from "@/components/ui/button";
import { useTypewriter } from "@/hooks/useTypewriter";
import { useState } from "react";

const N8N_WEBHOOK_URL = "http://localhost:5678/webhook-test/pancake-recipe";

function extractRecipeText(responseData: unknown): string {
  if (Array.isArray(responseData) && responseData.length > 0) {
    const firstItem = responseData[0] as Record<string, unknown>;
    if (typeof firstItem.text === "string") return firstItem.text;
    if (typeof firstItem.output === "string") return firstItem.output;
  }
  if (typeof responseData === "object" && responseData !== null) {
    const data = responseData as Record<string, unknown>;
    if (typeof data.text === "string") return data.text;
    if (typeof data.output === "string") return data.output;
  }
  return JSON.stringify(responseData, null, 2);
}

export default function App() {
  const [recipeText, setRecipeText] = useState("");
  const [isFetching, setIsFetching] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const { displayedText, isAnimating } = useTypewriter(recipeText);

  async function fetchRecipe() {
    setIsFetching(true);
    setError(null);
    setRecipeText("");

    try {
      const response = await fetch(N8N_WEBHOOK_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt: "Give me a fluffy American pancake recipe" }),
      });
      if (!response.ok) {
        throw new Error(`Request failed with status ${response.status}`);
      }
      const rawText = await response.text();
      if (!rawText.trim()) {
        throw new Error("Webhook returned an empty response");
      }
      const responseData: unknown = JSON.parse(rawText);
      setRecipeText(extractRecipeText(responseData));
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Something went wrong"
      );
    } finally {
      setIsFetching(false);
    }
  }

  const isDisabled = isFetching || isAnimating;

  return (
    <main className="min-h-screen flex flex-col items-center justify-start gap-8 p-8 pt-16">
      <div className="text-center space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">
          Pancake Recipe Generator
        </h1>
        <p className="text-muted-foreground text-sm">
          Powered by AI — get a fresh recipe on every click
        </p>
      </div>

      <Button onClick={fetchRecipe} disabled={isDisabled} size="lg">
        {isFetching ? "Fetching recipe…" : "Get Pancake Recipe"}
      </Button>

      {error && (
        <p className="text-sm text-destructive max-w-md text-center">{error}</p>
      )}

      <RecipeCard displayedText={displayedText} isAnimating={isAnimating} />
    </main>
  );
}
