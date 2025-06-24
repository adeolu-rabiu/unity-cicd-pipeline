using UnityEngine;
using UnityEngine.UI;

public class GameManager : MonoBehaviour
{
    [SerializeField] private Text scoreText;
    [SerializeField] private Button incrementButton;
    private int score = 0;

    void Start()
    {
        UpdateScoreDisplay();
        incrementButton.onClick.AddListener(IncrementScore);
    }

    public void IncrementScore()
    {
        score++;
        UpdateScoreDisplay();
        Debug.Log($"Score incremented to: {score}");
    }

    private void UpdateScoreDisplay()
    {
        if (scoreText != null)
            scoreText.text = $"Score: {score}";
    }
}

