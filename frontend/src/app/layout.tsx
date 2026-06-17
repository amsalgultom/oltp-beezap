import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { SessionProvider } from "@/components/providers/SessionProvider";
import { QueryProvider } from "@/components/providers/QueryProvider";
import { Toaster } from "sonner";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Beezap Analytics",
  description: "Analytics dashboard powered by Apache Superset",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <SessionProvider>
          <QueryProvider>
            {children}
            <Toaster richColors position="top-right" />
          </QueryProvider>
        </SessionProvider>
      </body>
    </html>
  );
}
