import React, { useRef, useEffect } from 'react';
import katex from 'katex';
import 'katex/dist/katex.min.css';

interface KaTeXRenderProps {
  text: string;
}

const KaTeXRender: React.FC<KaTeXRenderProps> = ({ text }) => {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const renderMath = () => {
      if (containerRef.current) {
        try {
          let processedText = text
            .replace(/\\qquad/g, '\\rule{2cm}{1pt}')
            .replace(/\\quad/g, '\\rule{1cm}{1pt}')
            .replace(/\$\$([^$]+)\$\$/g, (match, math) => {
              try {
                return katex.renderToString(math, { displayMode: true });
              } catch (e) {
                console.warn('KaTeX rendering failed for:', math);
                return match;
              }
            })
            .replace(/\$([^$]+)\$/g, (match, math) => {
              try {
                return katex.renderToString(math, { displayMode: false });
              } catch (e) {
                console.warn('KaTeX rendering failed for:', math);
                return match;
              }
            });

          containerRef.current.innerHTML = processedText;
        } catch (error) {
          console.error('KaTeX rendering error:', error);
          if (containerRef.current) {
            containerRef.current.textContent = text;
          }
        }
      }
    };

    renderMath();
  }, [text]);

  return (
    <div 
      ref={containerRef} 
      className="katex-container"
      style={{ minHeight: '1rem' }}
    />
  );
};

export default KaTeXRender;
