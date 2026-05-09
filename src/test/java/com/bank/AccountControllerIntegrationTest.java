package com.bank;

import com.bank.model.Account;
import com.bank.repository.AccountRepository;
import com.bank.repository.TransactionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AccountControllerIntegrationTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @Autowired private AccountRepository accountRepository;
    @Autowired private TransactionRepository transactionRepository;

    @BeforeEach
    void setUp() {
        transactionRepository.deleteAll();
        accountRepository.deleteAll();
    }

    @Test
    void createAccount_returns201() throws Exception {
        Account account = Account.builder()
                .accountNumber("ACC1001")
                .ownerName("Rohan DevOps")
                .email("rohan@devops.com")
                .type(Account.AccountType.SAVINGS)
                .balance(BigDecimal.valueOf(1000))
                .build();

        mockMvc.perform(post("/api/v1/accounts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(account)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accountNumber").isNotEmpty())
                .andExpect(jsonPath("$.ownerName").value("Rohan DevOps"));
    }

    @Test
    void getAccount_notFound_returns404() throws Exception {
        mockMvc.perform(get("/api/v1/accounts/INVALID999"))
                .andExpect(status().isNotFound());
    }

    @Test
    void transfer_success_returns200() throws Exception {
        Account acc1 = accountRepository.save(Account.builder()
                .accountNumber("TEST001")
                .ownerName("Sender")
                .email("sender@bank.com")
                .balance(BigDecimal.valueOf(5000))
                .type(Account.AccountType.SAVINGS)
                .active(true).build());

        accountRepository.save(Account.builder()
                .accountNumber("TEST002")
                .ownerName("Receiver")
                .email("receiver@bank.com")
                .balance(BigDecimal.valueOf(1000))
                .type(Account.AccountType.SAVINGS)
                .active(true).build());

        Map<String, String> request = Map.of(
                "fromAccountNumber", "TEST001",
                "toAccountNumber", "TEST002",
                "amount", "500",
                "description", "Integration test transfer"
        );

        mockMvc.perform(post("/api/v1/accounts/transfer")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.amount").value(500));
    }
}
