import { useState, useEffect } from "react";

interface UseTypewriterResult {
  displayedText: string;
  isAnimating: boolean;
}

export function useTypewriter(
  fullText: string,
  speedMs: number = 30
): UseTypewriterResult {
  const [displayedText, setDisplayedText] = useState("");
  const [isAnimating, setIsAnimating] = useState(false);

  useEffect(() => {
    if (!fullText) {
      setDisplayedText("");
      setIsAnimating(false);
      return;
    }

    const words = fullText.split(" ");
    let currentIndex = 0;
    setDisplayedText("");
    setIsAnimating(true);

    const interval = setInterval(() => {
      currentIndex += 1;
      setDisplayedText(words.slice(0, currentIndex).join(" "));

      if (currentIndex >= words.length) {
        clearInterval(interval);
        setIsAnimating(false);
      }
    }, speedMs);

    return () => clearInterval(interval);
  }, [fullText, speedMs]);

  return { displayedText, isAnimating };
}
