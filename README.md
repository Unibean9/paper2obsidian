# 📚 Paper2Obsidian: AI-Powered Research Manager

A modern, local-first Flutter desktop application designed to streamline the workflow of organizing academic research papers into [Obsidian](https://obsidian.md/). 

By leveraging AWS Bedrock, it automatically extracts critical metadata from PDFs and generates beautifully structured, Dataview-ready Markdown notes directly into your Obsidian Vault.

## ✨ Features

*   **Local-First Architecture:** Directly manipulates your local Obsidian file system. No cloud backend, zero subscription fees, and complete privacy for your research.
*   **AI Metadata Extraction:** Automatically extracts Title, Authors, Venue, Year, Keywords, Datasets, and limits using AWS Bedrock models.
*   **Human-in-the-Loop UI:** A clean, Material 3 dashboard to preview the PDF and review/edit the AI-extracted data before saving.
*   **Obsidian Graph Ready:** Automatically structures metadata into internal links (e.g., `[[Authors/John Doe]]`, `[[Venues/CVPR]]`) to instantly populate your Obsidian Graph View.
*   **Cross-Platform:** Built with Flutter, supporting Windows, macOS, and Linux desktop environments.

## 🚀 How It Works

1.  **Select:** Pick a research paper (PDF) from your computer.
2.  **Extract:** The app reads the paper text and sends it to AWS Bedrock for summary and metadata.
3.  **Review:** AI parses the text into a JSON object and populates the dashboard UI.
4.  **Save:** Click "Save to Obsidian". The app will:
    *   Copy the PDF to your Vault.
    *   Generate a structured `.md` file with YAML Frontmatter.
    *   Create metadata nodes (Authors, Tags, Venues) for Graph connections.


## 🛠 Prerequisites

To run or build this project, you will need:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Desktop support enabled)
*   [Obsidian](https://obsidian.md/) installed locally.
*   [AWS account](https://aws.amazon.com/) with [Amazon Bedrock](https://aws.amazon.com/bedrock/) access and a model enabled (e.g. Claude 3.5 Sonnet).
*   IAM credentials with `bedrock:InvokeModel` permission for your chosen model.

## 💻 Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/mintii13/paper_to_obsidan.git](https://github.com/mintii13/paper_to_obsidan.git)
   cd paper2obsidian
