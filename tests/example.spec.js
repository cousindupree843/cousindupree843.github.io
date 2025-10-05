const { test, expect } = require('@playwright/test');

test('homepage loads correctly', async ({ page }) => {
    await page.goto('http://example.com');
    await expect(page).toHaveTitle(/Example Domain/);
});