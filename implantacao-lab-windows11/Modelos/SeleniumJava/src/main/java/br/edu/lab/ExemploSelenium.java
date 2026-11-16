package br.edu.lab;

import org.openqa.selenium.WebDriver;
import org.openqa.selenium.edge.EdgeDriver;

public final class ExemploSelenium {
    private ExemploSelenium() {
    }

    public static void main(String[] args) {
        WebDriver driver = new EdgeDriver();
        try {
            driver.get("https://example.com/");
            System.out.println("Título: " + driver.getTitle());
        } finally {
            driver.quit();
        }
    }
}

