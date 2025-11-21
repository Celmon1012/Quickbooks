import type { Metadata } from "next";
import "./globals.css";
import RootLayout from "@/components/RootLayout";

export const metadata: Metadata = {
  title: "VIRGO Financial Dashboard",
  description: "SQL-first financial data pipeline and analytics platform for QuickBooks Online data",
};

export default function Layout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">
        <RootLayout>{children}</RootLayout>
      </body>
    </html>
  );
}
