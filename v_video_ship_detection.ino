#include <PDM.h>
#include <mzhang26_ship_detection_inferencing.h>

typedef struct {
    int16_t  *buf;
    uint32_t  buf_count;
    uint32_t  num_samples;
    uint8_t   buf_ready;
} audio_t;

static audio_t audio;
static int16_t mic_buf[512];
static int slices = 0;

void on_mic_data() {
    int bytes = PDM.available();
    PDM.read(mic_buf, bytes);
    int n = bytes / sizeof(int16_t);

    for (int i = 0; i < n; i++) {
        audio.buf[audio.buf_count++] = mic_buf[i];
        if (audio.buf_count >= audio.num_samples) {
            audio.buf_count = 0;
            audio.buf_ready = 1;
        }
    }
}

static int get_audio(size_t offset, size_t len, float *out) {
    numpy::int16_to_float(&audio.buf[offset], out, len);
    return EIDSP_OK;
}

void setup() {
    Serial.begin(115200);
    delay(2000);

    audio.num_samples = EI_CLASSIFIER_SLICE_SIZE;
    audio.buf_count   = 0;
    audio.buf_ready   = 0;
    audio.buf         = (int16_t *)malloc(EI_CLASSIFIER_SLICE_SIZE * sizeof(int16_t));

    PDM.onReceive(on_mic_data);
    PDM.setGain(80);
    PDM.begin(1, 16000);

    run_classifier_init();

    Serial.println("Listening...");
}

void loop() {
    if (!audio.buf_ready) return;
    audio.buf_ready = 0;

    signal_t sig;
    sig.total_length = EI_CLASSIFIER_SLICE_SIZE;
    sig.get_data   = &get_audio;

    ei_impulse_result_t res = { 0 };
    run_classifier_continuous(&sig, &res, false);

    slices++;
    if (slices < EI_CLASSIFIER_SLICES_PER_MODEL_WINDOW) return;
    slices = 0;

    Serial.println("-----------------------------");

    int   best_idx   = 0;
    float best_score = 0.0f;
    for (int i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
        if (res.classification[i].value > best_score) {
            best_score = res.classification[i].value;
            best_idx   = i;
        }
    }

    if (strcmp(res.classification[best_idx].label, "ship") == 0 && best_score > 0.9f) {
        Serial.println("no ship");
    } else if (best_score < 0.75f) {
        Serial.println("unsure");
    } else {
        Serial.println("ship detected");
    }

    for (int i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
        Serial.print("  ");
        Serial.print("confidence");
        Serial.print(": ");
        Serial.print(res.classification[i].value * 100, 1);
        Serial.println("%");
    }
    Serial.println();
}


