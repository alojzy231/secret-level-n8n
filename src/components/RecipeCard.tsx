import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface RecipeCardProps {
  displayedText: string;
  isAnimating: boolean;
}

export function RecipeCard({ displayedText, isAnimating }: RecipeCardProps) {
  return (
    <Card className="w-full max-w-2xl">
      <CardHeader>
        <CardTitle>Your Pancake Recipe</CardTitle>
      </CardHeader>
      <CardContent>
        {displayedText ? (
          <p className="text-sm leading-relaxed whitespace-pre-wrap">
            {displayedText}
            {isAnimating && (
              <span className="inline-block w-0.5 h-4 ml-0.5 bg-foreground animate-pulse align-middle" />
            )}
          </p>
        ) : (
          <p className="text-sm text-muted-foreground italic">
            Click the button above to get a freshly generated pancake recipe.
          </p>
        )}
      </CardContent>
    </Card>
  );
}
