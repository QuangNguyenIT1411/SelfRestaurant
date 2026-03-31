using System;
using System.Data.Entity;
using System.Linq;
using System.Net;
using System.Web.Mvc;
using SelfRestaurant.Controllers;
using SelfRestaurant.Filters;

namespace SelfRestaurant.Areas.Admin.Controllers
{
    [Authorize]
    [AdminOnly]
    public class CustomersController : BaseController
    {
        private RESTAURANTEntities db = new RESTAURANTEntities();

        // GET: Admin/Customers
        public ActionResult Index(string search, int page = 1)
        {
            ViewBag.ActiveNav = "Customers";

            var query = db.Customers.AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
            {
                query = query.Where(c =>
                    c.Name.Contains(search) ||
                    c.Username.Contains(search) ||
                    (c.PhoneNumber != null && c.PhoneNumber.Contains(search)) ||
                    (c.Email != null && c.Email.Contains(search)));
            }

            const int pageSize = 10;
            if (page < 1) page = 1;

            var ordered = query
                .OrderByDescending(c => c.CreatedAt)
                .ThenBy(c => c.Name);

            var totalItems = ordered.Count();
            var customers = ordered
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToList();

            ViewBag.SearchTerm = search;
            ViewBag.Page = page;
            ViewBag.TotalPages = (int)Math.Ceiling(totalItems / (double)pageSize);
            ViewBag.SuccessMessage = TempData["SuccessMessage"];
            ViewBag.ErrorMessage = TempData["ErrorMessage"];

            return View(customers);
        }

        // GET: Admin/Customers/Create
        public ActionResult Create()
        {
            ViewBag.ActiveNav = "Customers";
            var model = new Customers
            {
                IsActive = true
            };
            return View(model);
        }

        // POST: Admin/Customers/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Create([Bind(Include = "Name,Username,Password,PhoneNumber,Email,Address,Gender,DateOfBirth,LoyaltyPoints,IsActive")] Customers customer)
        {
            ViewBag.ActiveNav = "Customers";
            ValidateCustomer(customer, null);

            if (ModelState.IsValid)
            {
                customer.CreatedAt = DateTime.Now;
                customer.UpdatedAt = DateTime.Now;
                customer.IsActive = customer.IsActive;

                db.Customers.Add(customer);
                db.SaveChanges();

                TempData["SuccessMessage"] = "Thêm khách hàng thành công.";
                return RedirectToAction("Index");
            }

            return View(customer);
        }

        // GET: Admin/Customers/Edit/5
        public ActionResult Edit(int? id)
        {
            ViewBag.ActiveNav = "Customers";
            if (id == null)
            {
                return new HttpStatusCodeResult(HttpStatusCode.BadRequest);
            }

            var customer = db.Customers.Find(id);
            if (customer == null)
            {
                return HttpNotFound();
            }

            return View(customer);
        }

        // POST: Admin/Customers/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Edit([Bind(Include = "CustomerID,Name,Username,Password,PhoneNumber,Email,Address,Gender,DateOfBirth,LoyaltyPoints,IsActive")] Customers customer)
        {
            ViewBag.ActiveNav = "Customers";
            ValidateCustomer(customer, customer.CustomerID);

            var existing = db.Customers.Find(customer.CustomerID);
            if (existing == null)
            {
                return HttpNotFound();
            }

            if (ModelState.IsValid)
            {
                existing.Name = customer.Name;
                existing.Username = customer.Username;
                if (!string.IsNullOrWhiteSpace(customer.Password))
                {
                    existing.Password = customer.Password;
                }
                existing.PhoneNumber = customer.PhoneNumber;
                existing.Email = customer.Email;
                existing.Address = customer.Address;
                existing.Gender = customer.Gender;
                existing.DateOfBirth = customer.DateOfBirth;
                existing.LoyaltyPoints = customer.LoyaltyPoints;
                existing.IsActive = customer.IsActive;
                existing.UpdatedAt = DateTime.Now;

                db.SaveChanges();

                TempData["SuccessMessage"] = "Cập nhật khách hàng thành công.";
                return RedirectToAction("Index");
            }

            return View(customer);
        }

        // POST: Admin/Customers/Deactivate/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult Deactivate(int id)
        {
            var customer = db.Customers.Find(id);
            if (customer == null)
            {
                return HttpNotFound();
            }

            customer.IsActive = false;
            customer.UpdatedAt = DateTime.Now;
            db.SaveChanges();

            TempData["SuccessMessage"] = "Đã vô hiệu hóa khách hàng.";
            return RedirectToAction("Index");
        }

        private void ValidateCustomer(Customers customer, int? currentId)
        {
            if (string.IsNullOrWhiteSpace(customer.Username))
            {
                ModelState.AddModelError("Username", "Vui lòng nhập tên đăng nhập.");
            }

            var exists = db.Customers.Any(c => c.Username == customer.Username && c.CustomerID != currentId);
            if (exists)
            {
                ModelState.AddModelError("Username", "Tên đăng nhập đã tồn tại.");
            }

            if (!currentId.HasValue && string.IsNullOrWhiteSpace(customer.Password))
            {
                ModelState.AddModelError("Password", "Vui lòng nhập mật khẩu.");
            }
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                db.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
